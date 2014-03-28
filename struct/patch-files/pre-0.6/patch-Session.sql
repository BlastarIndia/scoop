#
# Patch to bring scoop DB up to date for 0.5.2
#
# Adds last_accessed timestamp column to the sessions table.
# This allows us to expire old rows with *musch* greater speed.
 
alter table sessions change column id id varchar(32) NOT NULL;
