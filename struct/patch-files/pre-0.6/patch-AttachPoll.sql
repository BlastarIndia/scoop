UPDATE box set content='
my $pollqid = shift @ARGS;
my $action = \'normal\';
my $preview = 0;
$preview = 1 if $S->{CGI}->param(\'op\') eq \'submitstory\';
$preview = 1 if $S->{CGI}->param(\'mode\') eq \'moderate\';

my $op = $S->{CGI}->param(\'op\');

# check to see if this is to display an attached poll by checking the sid parameter
# the reason for the crazy if stuff is to that the eval doesn\'t complain
my $attach_flag = (my $sid = $S->{CGI}->param(\'sid\'));
unless( $attach_flag ) {
    $attach_flag = $preview;
}

if ( $attach_flag ) {
    # of course return if they don\'t have any poll entered, so they don\'t see the current_poll
    return \'\' if ($S->{CGI}->param(\'question\') eq \'\' && $op eq \'submitstory\' );

    $sid = $S->{DBH}->quote($sid);

    unless( $S->{CGI}->param(\'preview\') eq \'Preview\' && $op eq \'submitstory\' ){
        my ($rv, $sth) = $S->db_select({
            WHAT => \'attached_poll\',
            FROM => \'stories\',
            WHERE => qq\|sid = $sid\| });
        if (my $att_poll = $sth->fetchrow()) {
            $pollqid = $att_poll;
        } else {
            warn "returning \'\' because not previewing and nothing attached to this sid";
            return \'\';
        }

    } else {    # if it gets here its a preview, so set the $action to preview
        $action = \'preview\';
        $pollqid = $S->{CGI}->param(\'editqid\');
  }
} 

$pollqid = $S->{UI}->{VARS}->{current_poll} if ($pollqid eq \'\');
return \'\' unless $pollqid;

my $poll_hash = $S->get_poll_hash( $pollqid, $action );

# first get the poll form all set up except for the answers
my $poll_form = qq\|
	<!-- begin poll form -->
	<FORM ACTION="%%rootdir%%/" METHOD="POST">
    <INPUT TYPE="hidden" NAME="op" VALUE="view_poll">
    <INPUT TYPE="hidden" NAME="qid" VALUE="$poll_hash->{\'qid\'}">
    <INPUT type="hidden" name="ispoll" value="1">\|;

$poll_form .= "<b>$poll_hash->{\'question\'}</b><br>";

# here is where all the answer fields get filled in
my $answer_array = $S->get_poll_answers($poll_hash->{\'qid\'}, $action);

# now check if they have already voted or haven\'t logged in
my $row;
if ( $S->_can_vote($poll_hash->{\'qid\'}) ) {
    foreach $row ( @{$answer_array} ) {	
        $poll_form .= qq\|
   	        <INPUT TYPE="radio" NAME="aid" VALUE="$row->{\'aid\'}"> $row->{\'answer\'}<BR>\|;
   	}
} else {
    my $total_votes = $poll_hash->{\'voters\'};

    if($total_votes == 0) {
        $total_votes = 1;  # so we don\'t get a divide by 0 error
    }

	$poll_form .= qq\|
		<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=0>\|;

	foreach $row ( @{$answer_array} ) {
		my $percent = int($row->{\'votes\'} / $total_votes * 100);
		$poll_form .= qq\|
			<TR>
				<TD valign="top">%%norm_font%%%%dot%%%%norm_font_end%%</TD>
				<TD valign="top">%%norm_font%%$row->{\'answer\'}%%norm_font_end%%</TD>
				<TD valign="top">%%norm_font%% $percent% %%norm_font_end%%</TD>
			</TR>\|;
   	}
	$poll_form .= qq\|
		</TABLE>\|;
		
}

# get the # of comments
my $comment_num = $S->poll_comment_num($poll_hash->{\'qid\'});
   
# only show the vote button if they havn\'t voted
if ( $S->_can_vote($poll_hash->{\'qid\'}) && ! $preview ) {
	$poll_form .= qq\|<BR><INPUT TYPE="submit" name="vote" VALUE="Vote">\|;
}


# now finish up the form
$poll_form .= qq{
	</FORM>
	<!-- end poll form -->
	<P>
	%%norm_font%%
    <TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 ALIGN="center">
	<TR>
	<TD>%%norm_font%%[ Votes: <b>$poll_hash->{\'voters\'}</b>%%norm_font_end%%</TD>
	<TD ALIGN="center" WIDTH=15>%%norm_font%%\|%%norm_font_end%%</TD>
	<TD ALIGN="right">%%norm_font%% Comments: <b>$comment_num</b> ]%%norm_font_end%%</TD></TR>
	<TR> };

if( $preview ) {
    $poll_form .= qq{
	<TD>%%norm_font%%[ Results%%norm_font_end%%</TD>
	<TD ALIGN="center" WIDTH=15>%%norm_font%%\|%%norm_font_end%%</TD>
    <TD ALIGN="right">%%norm_font%% Other Polls ]%%norm_font_end%%</TD></TR>
	};

} else {
    $poll_form .= qq{
	<TD>%%norm_font%%[ <a href="%%rootdir%%/?op=view_poll&qid=$poll_hash->{\'qid\'}">Results</a>%%norm_font_end%%</TD>
	<TD ALIGN="center" WIDTH=15>%%norm_font%%\|%%norm_font_end%%</TD>
    <TD ALIGN="right">%%norm_font%% <a href="%%rootdir%%/?op=poll_list&qid=$poll_hash->{\'qid\'}">Other Polls</a> ]%%norm_font_end%%</TD></TR>
	};
}

$poll_form .= qq{
	</TABLE>
	%%norm_font_end%%
	<!-- end poll content -->};

## don\'t forget to tell them its a poll preview if it is
if( $preview ) {
	$title = "Poll Preview";
}

if ($poll_form) {
	return qq\|%%norm_font%%$poll_form%%norm_font_end%%\|;
} else {
	return \'\';
}
' where boxid='poll_box';

