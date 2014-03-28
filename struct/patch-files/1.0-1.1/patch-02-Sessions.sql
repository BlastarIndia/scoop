DROP TABLE sessions;

CREATE TABLE sessions (
	session_id VARCHAR(32) NOT NULL,
	item VARCHAR(255) NOT NULL,
	value TEXT,
	serialized INT(1) DEFAULT 0,
	last_update DATETIME,
	PRIMARY KEY (session_id, item)
);
