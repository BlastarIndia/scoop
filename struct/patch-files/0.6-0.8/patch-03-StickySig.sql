INSERT INTO vars VALUES ('default_sig_behavior','regular','\'regular\' (new sigs apply to old comments) or \'sticky\' (persistant sigs that become part of the comment)','text','Comments');

INSERT INTO vars VALUES ('allow_sig_behavior','0','Set to 0 to disable users choosing between having a sticky sig (one that doesn\'t change on that comment when they change their sig) or regular sig (retroactive sig changes).  Warning: Depending on your placement of comment vs. sig in the comment block, sticky_sig/no_sig may not render correctly','bool','Comments');

ALTER TABLE comments ADD COLUMN sig_status int(1) DEFAULT 1;
