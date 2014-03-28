package Scoop;
use strict;

my $DEBUG = 0;

sub make_box {
	my $S = shift;
	my ($title, $content, $template, $box_name) = @_;
	
	$template =~ s/%%title%%/$title/g;
	$template =~ s/%%content%%/$content/g;
	$template =~ s/%%bid%%/$box_name/g;

	# test to see if I can get some comments output about the box into the html
	#$template = "<!-- Box '$box_name' Titled '$title' -->\n" . $template;
	#$template = $template . "<!-- X Box '$box_name' Titled '$title' -->\n";

	return $template;
}

sub run_box {
	my $S = shift;
	my $box_id = shift;
	my @ARGS = @_;

	return unless defined($S->{BOX_DATA}->{$box_id});

	my $data = $S->{BOX_DATA}->{$box_id};

	$data->{template} ||= $S->{UI}->{VARS}->{default_box_template} || 'box';
	my $tmpl_id = $data->{template};
	my $template = $S->{UI}->{BLOCKS}->{$tmpl_id};

	my $title = $data->{title};

	my $retval;
	warn "Child $$: Now running box $box_id\n" if ($DEBUG);
	eval {
		no strict 'refs';
		$retval = &{$S->{BOXES}.'::'.$box_id}($S, $title, $template, @ARGS);
	};
	if ( $@ ) {
		warn "run_box: $box_id failed with message: $@";
		return ($S->{UI}->{BLOCKS}->{box_failed_msg}, $data, $S->{UI}->{BLOCKS}->{error_box});
	}

	return wantarray ? ($retval, $data, $template) : $retval;
}

sub box_magic {
	my $S = shift;
	my $box_id = shift;

	my ($retval, $data, $template) = $S->run_box($box_id, @_);
	return $S->make_box('ERROR', "no box found for $box_id", $S->{UI}->{BLOCKS}->{box}, 'Error Box') unless $template;

	if(ref($retval) eq 'HASH') {
		return $S->make_box(
			($retval->{title} || $data->{title}),
			$retval->{content},
			($retval->{template} || $template),
			$box_id
		);
	} elsif ($retval && $retval ne '') {
		return $S->make_box(
			$data->{title}, $retval, $template, $box_id
		);
	}
	
	return '';
}

sub _load_box {
	my $S = shift;
	my $data = shift;
	
	my $code = $data->{content};
	my $box_id = $data->{boxid};
	
	warn "Reloading box $box_id\n" if $DEBUG;
	my $sandbox = 'sub { my ($S, $title, $template, @ARGS) = @_; 
	if ($S->{BOX_DATA}->{'.$box_id.'}->{user_choose} && $S->{prefs}->{displayed_boxes}) {
		return unless grep(/^'.$box_id.'$/, split(/,/, $S->{prefs}->{displayed_boxes}));
	}
'.$code.'
}';

	{
		no strict 'refs';
		warn "Evaling $box_id\n" if $DEBUG;
		*{"$S->{BOXES}::$box_id"} = eval( $sandbox );
		warn "Error loading box $box_id: $@" if $@;
	}
	
	return;
}

sub _make_template_boxes {
	my $S = shift;
	my $template_id = shift;
	
	my $template = $S->{UI}->{BLOCKS}->{$template_id};
	
	while ($template =~ /%%__box__(.*?)%%/g) {
		my $box_id = $1;
		my $formatted_box = $S->box_magic($box_id);
		$template =~ s/%%__box__$box_id%%/$formatted_box/;
	}

	return $template;
}


sub _count_new_sub {
	my $S = shift;
	my $count = 0;
	my $edit  = 0;
	my $min_score = $S->{UI}->{VARS}->{hide_story_threshold};
	
	my ($rv, $sth) = $S->db_select({
		WHAT  => "sid, aid, displaystatus",
		FROM  => "stories",
		WHERE => qq|(displaystatus = -2 AND score > $min_score) OR displaystatus = -3|
	});

	my $total = 0;
	while (my $story = $sth->fetchrow_hashref) {
		$total++;
		
		if ($story->{displaystatus} == -3) {
			$edit++;
			next;
		}
		
		next if $story->{aid} eq $S->{UID};
		
		
		my $sid = $S->dbh->quote($story->{sid});
		my ($rv2, $sth2) = $S->db_select({
			WHAT	=>	"vote",
			FROM	=>	"storymoderate",
			WHERE	=>	qq|sid = $sid AND uid = $S->{UID}|});
		
		$count++ if ($rv2 == 0);
		$sth2->finish;
	}
	$sth->finish;

	return wantarray ? ($count, $total, $edit) : $count;
}

1;
