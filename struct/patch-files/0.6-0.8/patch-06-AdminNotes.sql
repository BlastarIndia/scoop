ALTER table users ADD column admin_notes text;
INSERT into vars values ('allow_admin_notes','1','If set to 1, this creates a small field in the User Preferences page that only people with edit_user permissions can see.  This is so that admins may share information on problem users, or on changes made to accounts.','bool','Security,General');
