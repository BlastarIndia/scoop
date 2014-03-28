ALTER TABLE commentratings ADD COLUMN rating_time datetime DEFAULT '' NULL;
UPDATE commentratings SET rating_time = NOW();
