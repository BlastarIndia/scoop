alter table ad_types add column pos int(5) NOT NULL default 1;
alter table ad_info add column pos int(5) NOT NULL default 1;
alter table ad_info add index pos_idx (pos);
