create table post_throttle (
   uid int(11) DEFAULT '0' NOT NULL,
   created_time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
   post_lock int(1) DEFAULT '0' NOT NULL,
   lock_timeout int(11) DEFAULT '0' NOT NULL,
   PRIMARY KEY (uid)
);

# Add default vars for throttling
INSERT INTO vars VALUES ('rate_limit_minutes', 10, 'How many minutes to count toward rate');
INSERT INTO vars VALUES ('max_comments_submit', 5, 'How many comments max in time period');
INSERT INTO vars VALUES ('max_stories_submit', 4, 'How many stories max in time period');
INSERT INTO vars VALUES ('timeout_minutes', 3, 'How long to lock posts from violators, initially');
INSERT INTO vars VALUES ('max_timeout', 300, 'Max limit until users are locked out for good');
INSERT INTO special VALUES ('rate_warn','Warning: Posting rate exceeded','The page that explains what\'s going on when they exceed the defined post limit','You have exceeded this site\'s maximum posting rate. You are only allowed to post %%max_comments_submit%% comments or %%max_stories_submit%% stories in %%rate_limit_minutes%% minutes. Your user account is now locked from posting for %%timeout_minutes%% minutes, and further action may be taken by site administrators.');
INSERT INTO blocks VALUES ('admin_alert','scoop@thissite.com,scoop@othersite.org',NULL,NULL);
