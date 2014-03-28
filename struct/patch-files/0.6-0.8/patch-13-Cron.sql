CREATE TABLE cron (
	name		VARCHAR(20) NOT NULL,
	func		VARCHAR(20),
	run_every	INT,
	last_run	DATETIME DEFAULT '0000-00-00 00:00:00',
	enabled		INT(1) DEFAULT '1',
	PRIMARY KEY (name)
);

INSERT INTO cron (name, func, run_every, enabled) VALUES ('rdf', 'cron_rdf', 21600, 1);
INSERT INTO cron (name, func, run_every, enabled) VALUES ('rdf_fetch', 'cron_rdf_fetch', 3600, 1);
INSERT INTO cron (name, func, run_every, enabled) VALUES ('sessionreap', 'cron_sessionreap', 86400, 1);
INSERT INTO cron (name, func, run_every, enabled) VALUES ('storyreap', 'cron_storyreap', 604800, 0);
INSERT INTO cron (name, func, run_every, enabled) VALUES ('digest', 'cron_digest', 86400, 1);

UPDATE blocks SET block = CONCAT(block, ',\ncron') WHERE bid = 'opcodes';

UPDATE perm_groups SET group_perms = CONCAT(group_perms,',cron_admin') WHERE perm_group_id = 'Superuser';

INSERT INTO blocks (bid, block) VALUES ('cron_template', '<html>\n<head>\n<title>%%slogan%% %%%% Cron</title>\n</head>\n<body bgcolor="#FFFFFF"><pre>%%CONTENT%%</pre></body>\n</html>');

INSERT INTO templates (template_id, opcode) VALUES ('cron_template', 'cron');
