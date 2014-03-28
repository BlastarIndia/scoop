UPDATE blocks SET bid = 'diary_post_message' WHERE bid = 'diary_submission_message';
INSERT INTO blocks VALUES ('post_message','<P><FONT SIZE=\"+1\">Your entry has been automatically posted</FONT></P>','1','<P>This block is displayed below the story body when it has been auto-posted. It should be self-contained HTML.</P>','Stories','default','en');
UPDATE blocks SET block=REPLACE(block,'ACTION=\"/\"','ACTION=\"%%rootdir%%/\"') WHERE bid='edit_story_form';

