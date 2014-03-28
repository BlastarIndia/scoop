UPDATE stories SET time = '2000-07-10 16:04:09' WHERE sid = '2000/2/12/16148/2875';
UPDATE users SET seclev = '10000' WHERE seclev = '1000';
INSERT INTO vars VALUES ('seclev_editor','1000','Allow someone to be an editor of content, but not a super admin. Middle level admin, someone you don\'t want messing w/ your shi');
INSERT INTO vars VALUES ('seclev_super','10000','Seclev needed to edit vars/blocks, topics, sections, special pages.');
INSERT INTO vars VALUES ('seclev_vote','1','Seclev needed to vote on polls, moderate stories, comment rating, so on...');
INSERT INTO vars VALUES ('poll_num_ans','100','Allowed number of poll answers to be set.');
INSERT INTO vars VALUES ('dot','&nbsp;','dots before stuff?');
