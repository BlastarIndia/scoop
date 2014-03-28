ALTER TABLE stories DROP COLUMN commentcount;
ALTER TABLE stories ADD COLUMN attached_poll char(20);
