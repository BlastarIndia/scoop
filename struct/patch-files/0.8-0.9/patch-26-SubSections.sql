CREATE TABLE subsections (
   section varchar(32) NOT NULL,
   child varchar(32) NOT NULL,
   inheritable tinyint(1) DEFAULT '0' NOT NULL,
   invisible tinyint(1) DEFAULT '0' NOT NULL,
   time timestamp(14),
   PRIMARY KEY (section, child)
);

UPDATE blocks SET block = CONCAT(block, ",\nshow_hidden_sections") WHERE bid = 'perms';

INSERT INTO vars (name, value, description, type, category) VALUES ( 'charset', 'ISO-8859-1', 'This is the charater set passed within the Content-Type Header. \'ISO-8859-1\' is the default and will be used unless this variable is defined to be some other character set', 'text', 'General');

INSERT INTO vars (name, value, description, type, category) VALUES ( 'no_cache', '0', 'Set to 1 if you want scoop to send cache-prevention headers', 'bool', 'General');

INSERT INTO vars (name, value, description, type, category) VALUES ('enable_subsections', '1', 'Enable or Disable the subsections feature. The feature adds no user runtime queries but adds some optimied iterative processing of cached data.', 'bool', 'General');

INSERT INTO box (boxid, title, content, description, template, user_choose) VALUES ('section_title_subsections', 'null', 'my $content;\nmy $op = $S->{CGI}->param(\'op\');\nmy $section = $S->cgi->param(\'section\');\nif($op eq \'section\'){\n  if($S->{UI}->{VARS}->{enable_subsections}){\n    my @paths=$S->section_paths($section);\n    while(my $path=shift(@paths)){\n      $path=~s/\\/?$section$//;       # Remove if Current Section\n      $path=~s/([^\\/]+)/<\\/b>%%norm_font_end%%<a href="%%rootdir%%\\/section\\/$1">%%norm_font%%<b>$S->{SECTION_DATA}->{$1}->{title}<\\/b>%%norm_font_end%%<\\/a>%%norm_font%%<b>/g;\n      $path=~s/^<\\/b>%%norm_font_end%%//;   # Clean Up After Ourselves\n      $path=($path)?"%%norm_font%%<b>/</b>%%norm_font_end%%$path":\'\';\n      $content.=qq{<a href="%%rootdir%%/">%%norm_font%%<b>Home</b>%%norm_font_end%%</a>$path%%norm_font%%<b>/$S->{SECTION_DATA}->{$section}->{title}</b>%%norm_font_end%%<br>\\n};\n    } $content=~s/<\\/br>$//;\n  } else {\n    $content = $S->{SECTION_DATA}->{$section}->{title} || \'All Stories\';\n    $content = "%%title_font%%$content%%title_font_end%%";\n  }\n} else{ $content = \'%%title_font%%Latest News%%title_font_end%%\'; }\nreturn { content=>$content }\n', 'Display title of current section', 'blank_box', 0);

