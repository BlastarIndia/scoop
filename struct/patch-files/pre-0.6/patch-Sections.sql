alter table sections drop column artcount;
alter table sections drop column issue;
alter table sections drop column isolate;
alter table sections drop column qid;
alter table sections add column description text;
alter table sections add column icon varchar(255);
