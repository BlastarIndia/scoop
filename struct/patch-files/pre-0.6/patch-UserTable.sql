# patch to mysql db to add saving of the register e-mail
ALTER TABLE users ADD origemail VARCHAR(50) AFTER realemail;
UPDATE users SET origemail = realemail;

INSERT INTO vars VALUES ('enable_story_digests','1','1 to be able to email digests, 0 otherwise');
