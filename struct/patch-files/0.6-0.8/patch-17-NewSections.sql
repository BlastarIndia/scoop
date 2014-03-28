create table section_perms ( 
	group_id	varchar(50) NOT NULL,
	section		varchar(30) NOT NULL,
	sect_perms	text,
	PRIMARY KEY (group_id,section)
);
