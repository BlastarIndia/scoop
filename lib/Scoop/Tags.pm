=head1 Tags.pm

This file contains functions that relate to "tags," or user-input open-ended 
content organizing. This is also known as "folksonomy", and is hot hott HOTTTTT 
in the wanky world of blogging. Despite that, it's still a pretty cool idea. 
It can work in conjunction with or instead of sections and topics.
 
=cut

package Scoop;
use strict;
my $DEBUG = 0;

=over 4

=item * get_tags_as_string($sid)

Takes a story id and returns a list of tags connected to that story as a 
single string, with tags separated by commas

=cut

sub get_tags_as_string {
	my $S = shift;
	my $sid = shift;
	return '' unless $sid;
	my $tags = $S->get_tags($sid);
	return join(', ', @{$tags});
}

=item * get_tags($sid)

Takes a story id and returns an arrayref of tags associated with that story.

=cut

sub get_tags {
	my $S = shift;
	my $sid = shift;
	return '' unless $sid;
	if ( my $cached = $S->cache->fetch('tags_'.$sid) ) {
		warn "(get_tags) getting from cache" if $DEBUG;
		return $cached;
	}

	warn "(get_tags) updating cache" if $DEBUG;
	my $q_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		WHAT => 'tag',
		FROM => 'story_tags',
		WHERE => qq{sid = $q_sid},
		ORDER_BY => 'tag_order ASC'
	});

	my @tags;
	while (my $t = $sth->fetchrow()) {
		push @tags, $t;
	}
	$sth->finish();

	# update the cache
	$S->cache->store('tags_'.$sid, \@tags);
	return \@tags;
}

=item * save_tags($sid, $tags)

Takes a story id and a list of tags (as a single string, comma-delimited) and 
saves the individual tags in the tag table. Doesn't return anything.

=cut

sub save_tags {
	my $S = shift;
	my $sid = shift;
	my $tags = shift;

	return '' unless ($sid && $tags);
	my $old_tags = $S->clear_tags($sid);

	my $q_sid = $S->dbh->quote($sid);
	my @tags = split /\s*,\s*/, $tags;

	my $i = 0;
	my @cache;
	foreach my $tag (@tags) {
                # this ought to block blank tags
                next if $tag !~ /\w/;
		$tag = $S->filter_subject($tag);

		if ($S->var('wrap_long_lines')) {
			my $wrap_at = $S->var('wrap_long_lines_at');
			$tag =~ s/(\S{$wrap_at})/$1\n/g;
		}

		if ($S->var('maximum_tag_length')) {
			my $max = $S->var('maximum_tag_length');
			$tag =~ s/^(.{0,$max}).*$/$1/;
		}

		my $q_tag = $S->dbh->quote($tag);
		# gotta filter out '/' as '-', too
		$q_tag =~ s#/#-#g;
		my ($rv, $sth) = $S->db_insert({
			INTO => 'story_tags',
			COLS => 'sid, tag, tag_order',
			VALUES => qq{$q_sid, $q_tag, $i}
		});
		$sth->finish();
		push @cache, $tag; # after filtering, mind you
		$i++;
		last if ($S->var('maximum_tags_per_story') && $i >= $S->var('maximum_tags_per_story'));
	}

	# Stamp and update the cache
	$S->cache->stamp('tags_'.$sid);
	$S->cache->store('tags_'.$sid, \@cache);
	return;
}


=item * clear_tags($sid)

Takes a story id and erases the tags associated with that story in the 
database. Used mainly by save_tags() to clear out old tags in preparation 
for saving new ones. Returns the old tagset as a string 
(from get_tags_as_string()) so that your code can restore the old tags 
if something goes wrong.

=cut

sub clear_tags {
	my $S = shift;
	my $sid = shift;

	return unless $sid;
	# Get the existing tagset for backup
	my $tags = $S->get_tags_as_string($sid);

	my $q_sid = $S->dbh->quote($sid);

	my ($rv, $sth) = $S->db_delete({
		FROM => 'story_tags',
		WHERE => qq{sid = $q_sid}
	});
	$sth->finish();

	# Stamp and empty the cache
	$S->cache->remove('tags_'.$sid);
	$S->cache->stamp('tags_'.$sid);
	return $tags;
}


=item * story_tag_field([$sid], [$tags])

Create and return the field for entering and editing tags on a story page. 
Optionally pass in a string of space-delimited tags and an sid, otherwise it 
will look for these inputs in the cgi "tags" and "sid" param

=cut

sub story_tag_field {
	my $S    = shift;
	my $sid  = shift || $S->cgi->param('sid');
	my $tags = shift || $S->cgi->param('tags');
	
	my $keys;
	$keys->{value} = $tags;

	if ($sid && !$keys->{value}) {
		# get saved tags
		$keys->{value} = $S->get_tags_as_string($sid);
	}

	my $form = $S->{UI}->{BLOCKS}->{story_edit_tags};
	my $return = $S->interpolate($form, $keys);

	return $return;
}

=item * tag_display($sid)

Create and return the display formatted list of tags associated with a story.
Uses the block "tag_item_format" for each individual tag, and "tag_list_format" 
for the whole list. Items are joined together with "tag_list_joinwith"

=cut		

sub tag_display {
	my $S = shift;
	my $sid = shift;
	my $tags_in = $S->cgi->param('tags');
	
	return '' unless $sid || $tags_in;
	
	my $list_format = $S->{UI}->{BLOCKS}->{tag_list_format};
	my $item = $S->{UI}->{BLOCKS}->{tag_item_format};
	
	my $tags;
	if ($tags_in) {
		$tags_in = $S->filter_subject($tags_in);
		@{$tags} = split /\s*,\s*/, $tags_in;
	} else {
		$tags = $S->get_tags($sid);
	}
	
	my @list;
	foreach my $t (@{$tags}) {
		my $values;
		$values->{'tag'} = $t;
		$values->{'urltag'} = $S->urlify($t);
		push @list, $S->interpolate($item, $values);
	}
	
	return $S->interpolate($list_format, {
		tags_list => join($S->{UI}->{BLOCKS}->{tag_list_joinwith}, @list)
		});
}

=item * get_all_tags({cutoff=>[int], limit=>[int], displaystatus=>[int,int]})

Fetch an arrayref of hashrefs like {tag => [tag], c => [count]}. Optionally, 
pass a hashref with keys "cutoff" (int) indicating you want 
all tags with that number or more stories attached, or "limit" (int) 
telling it to limit itself to that number of results, starting from the most 
used tags. You may use either or both of these arguments.

=cut

sub get_all_tags {
	my $S = shift;
	my $args = shift;
	my $fetch;
	my $sort = $S->pref('tag_sort') eq 'count' ? 'c desc' : 'tag asc';
        if ($S->{UID} < 0){
                $sort = $S->session('tag_sort') eq 'count'  ? 'c desc' : 'tag asc';
  		}  

	$fetch = {
		WHAT => 'distinct tag, count(story_tags.sid) as c',
		FROM => 'story_tags LEFT JOIN stories USING(sid)',
		ORDER_BY => $sort,
		GROUP_BY => 'tag',
		DEBUG => $DEBUG
	};
	$args->{displaystatus} ||= [0,1];	# Set a Defalt
	if ( ref($args->{displaystatus}) eq 'ARRAY' ) {
		$fetch->{WHERE}.=qq{stories.displaystatus IN(}.
		join(', ',map{$S->dbh->quote($_)}(@{$args->{displaystatus}})).
		qq{)};
	} elsif ( defined($args->{displaystatus}) ) {
		$fetch->{WHERE}.=qq{stories.displaystatus = }.
			$S->dbh->quote($args->{displaystatus});
	}

        # the where clauses...
        unless ( $args->{perm_override} ) {
                # do perm-checking here
                warn "(get_all_tags) checking permissions..." if $DEBUG;
		my $disallowed= $S->get_disallowed_sect_sql('norm_read_stories');
                $fetch->{WHERE} .= (defined $fetch->{WHERE} && $disallowed)?qq{ AND $disallowed}:$disallowed;
        }

	$fetch->{GROUP_BY} .= qq| having c >= $args->{cutoff}| if ($args->{cutoff});
	$fetch->{LIMIT} = $args->{limit} if ($args->{limit});

	my ($rv, $sth) = $S->db_select($fetch);
	
	my @return;
	while (my $row = $sth->fetchrow_hashref()) {
		push @return, $row;
	}
	$sth->finish();
	
	return \@return;
}

=item * all_tags_page()

Generate a full list of tags. Tags are formatted with "tag_page_item" and 
the list wrapped in "tag_page_format". List items are joined with 
"tag_page_joinwith"

=cut

sub all_tags_page {
	my $S = shift;
	my $params=shift;
	my $list = $S->get_all_tags($params);
	my @all_tags;
	my $classes={ split(/\s*[\n,]\s*/,$S->var('tag_threshold_classes')) };
	foreach my $tag (@{$list}) {
		my $cssclass;	# This is where we store the class to use
		foreach my $threshold (sort { $a <=> $b } keys %$classes) {
			$cssclass=$classes->{$threshold} if $tag->{'c'} >= $threshold;
		}
		push(@all_tags,
			$S->interpolate($S->{UI}->{BLOCKS}->{tag_page_item},{
				'tag' => $tag->{tag},
				'num' => $tag->{'c'},
				'cssclass' => $cssclass,
				'urltag' => $S->urlify($tag->{tag})
			})
		);
	}
	
	return $S->interpolate($S->{UI}->{BLOCKS}->{tag_page_format},{
		'tags_list' => join($S->{UI}->{BLOCKS}->{tag_page_joinwith}, @all_tags)
	});
}

sub show_storiesbytag {
	my $S=shift;
	my $content;
	if(my $tag=$S->cgi->param('tag')){
		$S->{UI}{BLOCKS}{subtitle} = $tag;
		return $S->frontpage_view('tag');
	}else{
		$S->{UI}{BLOCKS}{subtitle} = qq{All Tags};
		return $S->all_tags_page({displaystatus => [0,1]});
	}
}

1;
