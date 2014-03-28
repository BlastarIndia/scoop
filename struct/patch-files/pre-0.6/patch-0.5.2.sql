#
# Patch to bring scoop DB up to date for 0.5.2
#
# Adds last_accessed timestamp column to the sessions table.
# This allows us to expire old rows with *musch* greater speed.
 
alter table sessions add column last_accessed TIMESTAMP(14);
