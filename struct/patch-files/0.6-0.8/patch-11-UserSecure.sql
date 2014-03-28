ALTER TABLE users ADD COLUMN creation_ip varchar(16) NOT NULL;
ALTER TABLE users ADD COLUMN creation_time datetime NOT NULL;
UPDATE users SET creation_time = NOW();
UPDATE users SET creation_ip = "127.0.0.1";
