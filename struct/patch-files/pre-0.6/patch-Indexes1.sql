create index sid_c_idx on comments (sid);
create index uid_c_idx on comments (uid);

create index qid_s_idx on sections (qid);

create index tid_st_idx on stories (tid);
create index aid_st_idx on stories (aid);
create index time_st_idx on stories (time);
create index section_st_idx on stories (section);
create index score_st_idx on stories (score);
create index rating_st_idx on stories (rating);

create index uid_sm_idx on storymoderate (uid);
