package Scoop;
use strict;

sub admin_main {
	my $S = shift;

	# if referer checking is on, do that now and skip out if the check fails
	if ($S->{UI}->{VARS}->{use_ref_check} && ($S->{REFERER} !~ m!^http://$S->{SERVER_NAME}!)) {
		$S->{UI}->{BLOCKS}->{CONTENT} = qq|<B>Sorry, Referer says you didn't come from the local server. Please try again.</B>|;
		return;
	}

	my $tool = $S->{CGI}->param('tool');
	$S->{UI}->{BLOCKS}->{subtitle} = 'Admin %%bars%% ';

	# see if the requested admin tool even exists
	my $t = $S->{ADMIN_TOOLS}->{$tool};
	
	# Check for multi-perm tools
	my $have_perm = 0;
	if ($t->{perm} =~ /,/) {
		my @perms = split /\s*,\s*/, $t->{perm};
		foreach my $p (@perms) {
			$have_perm = $S->have_perm($p);
			last if $have_perm;
		}
	} else {
		$have_perm	= $S->have_perm($t->{perm});
	}
	
	if ($t && $have_perm) {
		# find out what type of tool it is and run it the appropriate way
		if ($t->{is_box}) {
			$S->{UI}->{BLOCKS}->{CONTENT} = $S->run_box($t->{func});
		} else {
			my $func = $t->{func};
			$S->{UI}->{BLOCKS}->{CONTENT} = $S->$func();
		}
		# finish off the subtitle
		$S->{UI}->{BLOCKS}->{subtitle} .= $t->{dispname};
	} else {
		# throw an error
		$S->{UI}->{BLOCKS}->{CONTENT} = qq|%%norm_font%%<H2>Permission Denied.</H2>%%norm_font_end%%|;
		$S->{UI}->{BLOCKS}->{subtitle} = 'Error!';
	}

	return;
}

sub moderate_subs {
	my $S = shift;

	my $content;
	unless ($S->have_perm( 'moderate' )) {
		$content = qq|
			<TABLE WIDTH="100%" BORDER=0 CELLPADDING=0 CELLSPACING=0>
			<TR BGCOLOR="%%title_bgcolor%%">
				<TD>%%title_font%%Permission Denied.%%title_font_end%%</TD>
			</TR>
			<TR><TD>%%norm_font%%Sorry, but you can only moderate stories if you have a valid user account. 
			Luckily for you, making one is easy! Just <A HREF="%%rootdir%%/?op=newuser">go here</A> to get started.
			%%norm_font_end%%</TD></TR>
			</TABLE>|;
		$S->{UI}->{BLOCKS}->{subtitle} = 'Error!';
	} else {
		$content = $S->list_stories('mod');
		$S->{UI}->{BLOCKS}->{subtitle} = 'Moderate Submissions';
	}
	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
	return;
}
1;
