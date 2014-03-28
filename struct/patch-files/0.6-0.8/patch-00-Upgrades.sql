create table patches (
	scoop_ver		varchar(20) NOT NULL,
	patch_num		int(2) NOT NULL,
	patch_name		varchar(30),
	patch_type		varchar(10) NOT NULL,
	PRIMARY KEY (scoop_ver,patch_num,patch_type)
);


