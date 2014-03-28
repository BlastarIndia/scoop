# this inserts the poll_block row into blocks
insert into blocks values ('poll_block', '<TR>
<TD>
<TABLE WIDTH=100% BORDER=0 CELLPADDING=1 CELLSPACING=0>
<TR>
<TD BGCOLOR="%%title_bgcolor%%" colspan=2>
%%title_font%%<B>%%title%%</B></FONT>
</TD>
</TR>

<TR>
<TD BGCOLOR="%%topic_bg%%">
%%norm_font%%
%%info%%
</FONT>
</TD>
<TD BGCOLOR="%%topic_bg%%" align="right">
%%norm_font%%%%hotlist%%</FONT>
</TD>
</TR>
<tr><td><br></td></tr>
%%poll_image%%
</TABLE>
</TD></TR>', NULL, NULL);

# this inserts the new current_poll var into vars
insert into vars values ('current_poll', NULL, "The qid of the current poll");

## These 3 tables are copies of the one's used in slashcode.
## I used them here because of good design, and why reinvent the
## wheel?  ... too much :)

# Table structure for table 'pollanswers'
#
CREATE TABLE pollanswers (
   qid char(20) DEFAULT '' NOT NULL,
   aid int(11) DEFAULT '0' NOT NULL,
   answer char(255),
   votes int(11),
   PRIMARY KEY (qid,aid) );

#
# Table structure for table 'pollquestions'
#
CREATE TABLE pollquestions (
   qid char(20) DEFAULT '' NOT NULL,
   question char(255) DEFAULT '' NOT NULL,
   voters int(11),
   post_date datetime,
   PRIMARY KEY (qid) );

#
# Table structure for table 'pollvoters'
#
CREATE TABLE pollvoters (
   qid char(20) DEFAULT '' NOT NULL,
   id char(35) DEFAULT '' NOT NULL,
   time datetime,
   uid int(11) DEFAULT '-1' NOT NULL,
   user_ip	char(15) NOT NULL,
   KEY qid (qid,id,uid) );
