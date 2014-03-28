ALTER TABLE stories ADD COLUMN to_archive tinyint(1) default 0;
ALTER TABLE comments ADD COLUMN to_archive tinyint(1) default 0;

ALTER TABLE stories ADD index archive_idx (to_archive);
ALTER TABLE comments ADD index archive_idx (to_archive);
