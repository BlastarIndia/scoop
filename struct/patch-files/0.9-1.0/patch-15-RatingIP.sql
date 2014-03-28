ALTER TABLE commentratings ADD COLUMN rater_ip varchar(16) NOT NULL;
ALTER TABLE comments ADD COLUMN pre_rating decimal(4,2) DEFAULT NULL;
INSERT INTO vars VALUES ('rating_labels','','Text labels for ratings. Comma-separated list, in lowest to highest order.','text','Comments');
INSERT INTO vars VALUES ('minimum_ratings_to_count','1','The smallest number of distinct ratings required before a comment\'s rating actually affects anything.','num','Comments');
INSERT INTO vars VALUES ('filter_ratings_by_ip',NULL,'Set true to ignore all but the first rating from the same IP address.','bool','Comments');
INSERT INTO vars VALUES ('default_hidingchoice','untilrating','Default value for the \"Show Hidden Comments\" pref. Possible values are \'no\', \'yes\', and \'untilrating\'','text','Comments');
INSERT INTO vars VALUES ('hide_rating_value',NULL,'Value for the \"Hide\" rating. Defaults to (rating_min - 1), but can be any value you put here','num','Comments');
