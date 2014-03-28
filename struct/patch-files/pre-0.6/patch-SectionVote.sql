alter table storymoderate add section_only enum('N','Y') not null default 'N';

update storymoderate set section_only = 'N' where section_only not in ('N','Y') or section_only is NULL;
