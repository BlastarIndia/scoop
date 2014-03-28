ALTER TABLE vars ADD COLUMN type varchar(5) DEFAULT 'text' NOT NULL;
ALTER TABLE vars MODIFY COLUMN description text;
ALTER TABLE vars ADD COLUMN category varchar(128) DEFAULT '' NOT NULL;

UPDATE vars SET type = 'bool' WHERE name = 'show_dept' OR name = 'story_count_words' OR name = 'use_mojo' OR name = 'use_topics' OR name = 'use_ref_check' OR name = 'enable_story_digests' OR name = 'auto_post_alert' OR name = 'use_auto_post' OR name = 'allow_ballot_stuffing' OR name = 'use_db_cache' OR name = 'use_diaries';

UPDATE vars SET type = 'num' WHERE name = 'maxstories' OR name = 'maxtitles' OR name = 'storylist' OR name = 'post_story_threshold' OR name = 'hide_story_threshold' OR name = 'rating_max' OR name = 'poll_num_ans' OR name = 'max_comments_submit' OR name = 'max_stories_submit' OR name = 'rate_limit_minutes' OR name = 'timeout_minutes' OR name = 'max_timeout' OR name = 'template_recurse' OR name = 'auto_post_frontpage' OR name = 'auto_post_section' OR name = 'max_rdf_intro' OR name = 'rating_min' OR name = 'max_intro_chars' OR name = 'max_intro_words';

UPDATE vars SET category = 'Comments' WHERE name = 'default_comment_view' OR name = 'default_comment_display' OR name = 'default_comment_order' OR name = 'rating_min' OR name = 'rating_max' OR name = 'default_comment_sort' OR name = 'use_mojo' OR name = 'default_post_type';
UPDATE vars SET category = 'Fonts' WHERE name = 'norm_font_end' OR name = 'box_title_font' OR name = 'title_font_end' OR name = 'norm_font_face' OR name = 'title_font' OR name = 'box_title_font_end' OR name = 'norm_font_size' OR name = 'norm_font';
UPDATE vars SET category = 'General' WHERE name = 'rootdir' OR name = 'imagedir' OR name = 'slogan' OR name = 'sitename' OR name = 'local_email' OR name = 'topics' OR name = 'time_zone' OR name = 'template_recurse' OR name = 'use_db_cache' OR name = 'db_cache_max' OR name = 'site_url';
UPDATE vars SET category = 'Polls' WHERE name = 'current_poll' OR name = 'poll_img' OR name = 'poll_num_ans' OR name = 'allow_ballot_stuffing';
UPDATE vars SET category = 'Post Throttle' WHERE name = 'rate_limit_minutes' OR name = 'timeout_minutes' OR name = 'max_timeout';
UPDATE vars SET category = 'Security' WHERE name = 'use_ref_check';
UPDATE vars SET category = 'Stories' WHERE name = 'maxstories' OR name = 'storylist' OR name = 'maxtitles' OR name = 'post_story_threshold' OR name = 'hide_story_threshold' OR name = 'show_dept' OR name = 'story_count_words' OR name = 'use_topics' OR name = 'enable_story_digests' OR name = 'auto_post_alert' OR name = 'use_auto_post' OR name = 'auto_post_frontpage' OR name = 'auto_post_section' OR name = 'max_intro_words' OR name = 'max_intro_chars' OR name = 'use_diaries';
UPDATE vars SET category = 'RDF' where name = 'max_rdf_intro';
UPDATE vars SET category = 'Comments,Post Throttle' WHERE name = 'max_comments_submit';
UPDATE vars SET category = 'Stories,Post Throttle' WHERE name = 'max_stories_submit';

