--
-- Updates to block table for HTML removed from scoop
--

--
-- Removed from Scoop.pm
--

INSERT INTO blocks VALUES ('login_error_message','%%norm_font%%<FONT COLOR=\"#FF0000\"><B>Login Incorrect</B></FONT>%%norm_font_end%%<BR>','2','Error message that appears in the login box when an incorrect login is attempted','content','default','en');
INSERT INTO blocks VALUES ('login_mailed_message','%%norm_font%%<FONT COLOR=\"#FF0000\"><B>Confirmation for %%uname%% mailed.</B></FONT>%%norm_font_end%%<BR>','2','Message to inform the user that a password request has been mailed to them','content','default','en');
INSERT INTO blocks VALUES ('login_mail_failed','%%norm_font%%<FONT COLOR=\"#FF0000\"><B>Could not mail confirmation for %%uname%%.</B></FONT>%%norm_font_end%%<BR>','2','Inform the user that an attempt to send a password change message has failed','content','default','en');

--
-- Removed from Interface.pm
--

INSERT INTO blocks VALUES ('user_prefs_message','<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width=\"100%\">\r\n                <TR>\r\n                        <TD BGCOLOR=\"%%title_bgcolor%%\">\r\n                        %%title_font%%<B>Sorry!</B>%%title_font_end%%\r\n                        </TD>\r\n                </TR>\r\n                <TR>\r\n                        <TD>%%norm_font%%\r\n                        Sorry, you can only edit user preferences if you have a user account. Why not <A HREF=\"%%rootdir%%/?op=newuser\">make one</A>?\r\n                        %%norm_font_end%%\r\n                        </TD>\r\n                </TR>\r\n                </TABLE>','2','Message shown when an unlogged-in user attempts to set their display preferences.','content','default','en');
INSERT INTO blocks VALUES ('interface_prefs_main_form','                <TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width=\"100%\">\r\n                <TR>\r\n                        <TD BGCOLOR=\"%%title_bgcolor%%\">\r\n                        %%title_font%%<B>Edit Interface Preferences for %%nickname%%</B>%%title_font_end%%\r\n                        </TD>\r\n                </TR>\r\n                <TR>\r\n                        <TD ALIGN=\"center\">%%title_font%%\r\n                        <P><FONT COLOR=\"#FF0000\">%%title_msg%%</FONT><P>%%title_font%%\r\n                        </TD>\r\n                </TR>\r\n                <TR>\r\n                        <TD>\r\n\r\n                        %%interface_form%%\r\n                        </TD>\r\n                </TR>\r\n                </TABLE>','2','Main form for the Display Preferences option.\r\nnickname = Users nick.\r\ntitle_msg = Title message\r\ninterface_form = The actual form.','content','default','en');

--
-- Removed from Comments.pm
--

INSERT INTO blocks VALUES ('comment_posted_message','                        <TR>\r\n                                <TD BGCOLOR=\"%%title_bgcolor%%\" WIDTH=\"100%\">\r\n                                        %%title_font%%<A NAME=\"here\">Comment posted!</A> Thank you for contributing.  %%title_font_end%%\r\n                                </TD>\r\n                        </TR>\r\n                        <TR>\r\n<TD>','2','','content','default','en');

--
-- Remove unused columns from comments table
--

ALTER TABLE comments DROP COLUMN name, DROP COLUMN email, DROP COLUMN url, DROP COLUMN host_name;
