package Scoop;
use strict;
my $DEBUG = 0;

sub check_do_static {
	my $S = shift;
	
	return 0 unless ($S->{UI}->{VARS}->{use_static_pages} && 
	                 $S->{UI}->{VARS}->{page_path} &&
					 $S->{GID} eq 'Anonymous');
	
	return 0 unless ($S->cgi()->param('op') eq 'displaystory');
	
	# Don't cache pages that aren't actually stories!
	my $sid = $S->cgi->param('sid');
	return 0 unless ($S->_check_for_story($sid));
	
	#($S->{UID} == -1) && (
	my $commenttype   = $S->get_comment_option('commenttype');
	my $commentorder  = $S->get_comment_option('commentorder');
	my $commentrating = $S->get_comment_option('commentrating');
	my $commentmode   = $S->get_comment_option('commentmode');
	my $ratingchoice  = $S->get_comment_option('ratingchoice');
	
	my $static_page = join("_", $commenttype, $commentorder, $commentrating, $commentmode, $ratingchoice);
	warn "Static page should be tried. Modifier is <$static_page>\n" if $DEBUG;
	return $static_page;
}

sub make_static_path {
	my $S = shift;
	my $page_mod = shift;
	
	my $base_path = $S->{UI}->{VARS}->{page_path};
	my $sid = $S->cgi->param('sid');
	my $path = $base_path.'/'.$sid.'_'.$page_mod;
	warn "Full static page path is <$path>\n" if $DEBUG;
	return $path;
}

sub get_static_page {
	my $S = shift;
	my $page_mod = shift;
	my $sid = $S->cgi->param('sid');
	
	# Don't look if user is trusted
	return undef if ($S->{UI}->{VARS}->{use_mojo} && 
	                 (($S->{TRUSTLEV} == 2) || ($S->have_perm('super_mojo'))));

	# Also is the story is not posted yet
	return undef if ($S->_check_story_mode($sid) < 0);
	
	my $full_path = $S->make_static_path($page_mod);
	
	unless (-e $full_path && -r $full_path) { 
		warn "Static file <$full_path> does not exist, or isn't readable.\n" if $DEBUG;
		return undef;
	}
	
	open STATIC, "<$full_path" || {warn "Can't open $full_path: $!\n" and return undef};
	my @file_info = stat STATIC;
	
	warn "Block time is ".$S->cache->refresh_one('blocks').", Var time is ".$S->cache->refresh_one('vars').", File time is $file_info[9]\n" if $DEBUG;

	# Check cache time for blocks and vars
	unless (($S->cache->refresh_one('blocks') <= $file_info[9]) &&
	        ($S->cache->refresh_one('vars')   <= $file_info[9])) {
		warn "Block or Var stamps invalid.\n" if $DEBUG;
		return undef;
	}

	warn "Blocks and vars still clean.\n" if $DEBUG;;

	# Check cache time for story
	my $resource = $sid.'_mod';
	
	unless ($S->cache->refresh_one($resource) <= $file_info[9]) {
		warn "$resource time is ".$S->cache->refresh_one($resource).", file time is $file_info[9]\n" if $DEBUG;
		return undef;
	}
	
	warn "Static page is good. Returning.\n" if $DEBUG;
	# Ok, so the page is valid. Pull it in, and return it
	my $stat_file;
	{ local $/; $stat_file = <STATIC> }
	close STATIC;
	
	# If we're a regular user, need to mark the comments
	$stat_file = $S->mark_new_comments($stat_file, $sid) unless ($S->{UID} == -1);
	
        # Set the page's subtitle properly
	my $q_sid = $S->dbh->quote($sid);
        my ($rv, $sth) = $S->db_select({
                ARCHIVE => $S->_check_archivestatus($sid),
                WHAT => 'title',
                FROM => 'stories',
                WHERE => qq|sid = $q_sid|
        });
        $S->{UI}->{BLOCKS}->{subtitle} .= $sth->fetchrow;
        $sth->finish;
        $S->{UI}->{BLOCKS}->{subtitle} =~ s/</&lt;/g;
        $S->{UI}->{BLOCKS}->{subtitle} =~ s/>/&gt;/g;

	# And the ratings! Put something here.
	
	return $stat_file;
}


sub mark_new_comments {
	my $S = shift;
	my $file = shift;
	my $sid = shift;
	return $file unless ($S->{UID} >= 0);
	warn "Running mark_new_comments\n" if $DEBUG;
	
	my $highest = $S->story_highest_index($sid);
	my $last = $S->fetch_highest_cid($sid);

	$highest++;
	warn "Last: $last, Highest: $highest\n" if $DEBUG;
	while ($highest <= $last) {
		my $key = '%%new_'.$highest.'%%';
		#warn "Replacing for $key\n";
		$file =~ s/$key/$S->{UI}->{BLOCKS}->{new_comment_marker}/g;
		$highest++;
	}
	
	$S->update_seen_if_needed($sid);
	return $file;
}


sub write_static_page {
	my $S = shift;
	my $page_mod = shift;
	my $sid = $S->cgi->param('sid');
	
	
	# Don't save if user is trusted, to avoid over-complication
	# with hidden comments, or if the story isn't posted yet
	unless ((
	         $S->{UI}->{VARS}->{use_mojo} && 
	         (($S->{TRUSTLEV} == 2) || ($S->have_perm('super_mojo')))
			) ||
			($S->_check_story_mode($sid) < 0) ||
			($S->{GID} ne 'Anonymous')) {
	
		my $full_path = $S->make_static_path($page_mod);

		my $page = $S->{UI}->{BLOCKS}->{$S->{CURRENT_TEMPLATE}};
		$page =~ s/%%STORY%%/$S->{UI}->{BLOCKS}->{STORY}/g;
		$page =~ s/%%COMMENTS%%/$S->{UI}->{BLOCKS}->{COMMENTS}/g;
		$page =~ s/%%CONTENT%%/$S->{UI}->{BLOCKS}->{CONTENT}/g;
		$S->make_cache_dir_path($full_path);

		open STAT, ">$full_path" || {warn "Can't open $full_path: $!\n" and return undef};
		print STAT $page || warn "Can't print to $full_path: $!\n";
		close STAT;

		warn "Wrote new cache file $full_path\n" if $DEBUG;

		# Make sure the story has a time stamp

		my $resource = $sid.'_mod';

		unless ($S->cache->refresh_one($resource)) {
			my $time = time();
			warn "Stamping $resource at $time\n" if $DEBUG;
			$S->cache->stamp_cache($resource, $time, 1);
		}
	}
	
	
	# Process new comments now too, for return
	if ($S->{UID} >= 0) {
		warn "Marking new comments\n" if $DEBUG;
		$S->{UI}->{BLOCKS}->{COMMENTS} = $S->mark_new_comments($S->{UI}->{BLOCKS}->{COMMENTS}, $sid);
	}
	
	return 1;
}

sub make_cache_dir_path {
	my $S = shift;
	my $path = shift;
	
	$path =~ s/^$S->{UI}->{VARS}->{page_path}\///;
	my $pre_path = $S->{UI}->{VARS}->{page_path};
	
	my @elem = split '/', $path;
	pop @elem;
	
	foreach my $dir (@elem) {
		$pre_path .= '/'.$dir;
		unless (-d $pre_path) {
			warn "Making directory $pre_path\n" if $DEBUG;
			mkdir ($pre_path, 0755) || warn "Can't create directory $pre_path: $!\n";
		}
	}
}
		
1;
