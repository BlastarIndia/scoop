INSERT INTO vars VALUES ('use_new_scoring','0','0 means add the votes for and against together, 1 means compare to the thresholds by themselves.');
DELETE FROM blocks WHERE bid = 'moderation';
INSERT INTO vars VALUES ('seclev_post','0','Seclev needed to submit a story or post a comment. 0 = anon. 1 = regular user.');
INSERT INTO vars VALUES ('seclev_moderate','0','Seclev needed to moderate a story');
INSERT INTO blocks VALUES ('story_separator', '<HR WIDTH=300 SIZE=1 NOSHADE>', NULL, '10000');
INSERT INTO blocks VALUES ('vote_console','%%moderation_guidelines%%<TR><TD><TABLE BGCOLOR="#006699" BORDER=0 CELLPADDING=1 CELLSPACING=0 WIDTH="100%" ALIGN="center"><TR><TD> <TABLE BGCOLOR="%%story_mod_bg%%" BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH="100%" ALIGN="center"> <TR><TD> <TABLE BORDER=0 CELLPADDING=3 CELLSPACING=0 WIDTH="100%"> <TR><TD>%%norm_font%%Your vote really does count! <B>You</B> decide whether this story ever sees the light of the front page. For more information on story voting, please see <A HREF="/?op=special;page=modguide">the Story Moderation Guidelines</A>. Then vote! </FONT></TD></TR> </TABLE> </TD></TR> <TR><TD ALIGN="center" VALIGN="middle"> %%norm_font%% %%vote_form%% </FONT></TD></TR></TABLE></TD></TR></TABLE></TD></TR><TR><TD><FONT COLOR="#FFFFFF">.</FONT></TD></TR>',NULL,'1');
INSERT INTO vars VALUES ('seclev_vote_poll','1','Seclev needed to vote on polls');
INSERT INTO blocks VALUES ('attach_poll_message','<TR><TD><BR><BR>%%norm_font%%Fill out the form below to attach a poll.  If you don\'t fill it out no poll will be attached.</FONT></TD></TR>',NULL,NULL);
INSERT INTO vars VALUES ('seclev_attach_poll','1','Seclev needed to attach a poll to a story as you create it');
