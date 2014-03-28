INSERT INTO vars VALUES ('use_mojo','1','Should we use the mojo system at all? 1/0 (1 Recommended!)');
INSERT INTO vars VALUES ('mojo_max_comments','30','How many comments count toward mojo?');
INSERT INTO vars VALUES ('mojo_max_days','60','How many days, max, count toward mojo?');
INSERT INTO vars VALUES ('mojo_min_trusted','10','How many comments must a user have to be trusted?');
INSERT INTO vars VALUES ('mojo_rating_trusted','3.5','What mojo makes you a candidate for trusted?');
INSERT INTO vars VALUES ('mojo_min_untrusted','3.5','How many comments does a user have to be untrusted?');

ALTER TABLE users ADD COLUMN mojo decimal(4,2);
ALTER TABLE users CHANGE seclev trustlev int(1) DEFAULT 1 NOT NULL;
UPDATE users SET trustlev = 1;

ALTER TABLE comments ADD COLUMN point_temp decimal(4,2) DEFAULT NULL;
UPDATE comments SET point_temp = points  WHERE points != "0.00";
ALTER TABLE comments DROP COLUMN points;
ALTER TABLE comments CHANGE point_temp points decimal(4,2) DEFAULT NULL;
