# It's bestnot to run the following on a live site! Take
# it down temporarily to update these...
alter table stories drop index normal;
alter table stories drop index sid_s_idx;
alter table stories drop index disp_stat_idx;
alter table stories drop index section_st_idx;
alter table stories add index section_idx (section, displaystatus);
alter table stories add index displaystatus_idx (displaystatus);
alter table viewed_stories add index hotlist_idx (uid, hotlisted);
