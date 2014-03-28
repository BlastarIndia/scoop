CREATE TABLE whos_online (
	ip varchar(16) NOT NULL default '',
	uid int(11) NOT NULL default '0',
	last_visit timestamp NOT NULL default '0000-00-00 00:00:00',
	PRIMARY KEY (ip)
);

INSERT INTO vars VALUES ('use_whosonline','0','Enable using a database table to keep track of who\'s online and the number of visitors?','bool','General');
