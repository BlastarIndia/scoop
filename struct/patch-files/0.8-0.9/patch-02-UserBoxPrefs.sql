ALTER TABLE box ADD COLUMN user_choose INT(1) DEFAULT '0';
ALTER TABLE box ADD INDEX user_choose_idx (user_choose);
UPDATE box SET user_choose = 1 WHERE boxid = 'hotlist_box' OR boxid = 'poll_box' OR boxid = 'rdf_feeds' OR boxid = 'top_hotlisted' OR boxid = 'whos_online';
UPDATE box SET title = 'Your Hotlist' WHERE boxid = 'hotlist_box';
