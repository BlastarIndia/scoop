alter table storymoderate change column section_only section_only enum('N','Y','X') DEFAULT 'X' NOT NULL;
update storymoderate set section_only = 'X' where vote < 1;
