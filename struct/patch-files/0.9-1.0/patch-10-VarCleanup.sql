INSERT IGNORE INTO vars VALUES ('disable_story_navbar', 0, 'If 1, hides the navigation bar at the bottom of the stories', 'bool', 'Stories');
INSERT IGNORE INTO vars VALUES ('end_voting_threshold', -1, 'If use_auto_post is on, this is the number of total votes that will force a posting decision if neither the post nor the drop threshold is reached.', 'num', 'Stories');
INSERT IGNORE INTO vars VALUES ('use_alternate_scoring', 0, 'If disabled, the post and hide thresholds are both compared to a story''s total score. If enabled, the thresholds are compared to the positive votes and negative votes, respectively.', 'bool', 'Stories');
INSERT IGNORE INTO vars VALUES ('front_page_ratio', 0.5, 'If the number of front-page votes divided by the number of total (section + frontpage) votes is larger than this, the story is posted to the front page', 'num', 'Stories');
INSERT IGNORE INTO vars VALUES ('cookie_expire', 2592000, 'How long before the cookie should expire, in sections (default is equivalent to 30 days)', 'num', 'General');
INSERT IGNORE INTO vars VALUES ('rdf_creator', '', 'A string used as the creator of the RDF, if different than sitename', 'text', 'RDF');
INSERT IGNORE INTO vars VALUES ('rdf_publisher', '', 'A string used as the publisher of the RDF, if different than sitename', 'text', 'RDF');
INSERT IGNORE INTO vars VALUES ('user_theme_default', '', 'The theme to use if the user has not set their preferences for the theme they would prefer.', 'text', 'Themes');
INSERT IGNORE INTO vars VALUES ('rdf_fetch_timeout', 60, 'The timeout in seconds before giving up fetching another site''s RDF', 'num', 'RDF');
INSERT IGNORE INTO vars VALUES ('hide_diary_search', 0, 'If 1, diaries cannot be found using the search form', 'bool', 'Stories');
INSERT IGNORE INTO vars VALUES ('hide_disabled_comments', 0, 'If 1, comments in stories that have disabled comments are not available as search results', 'bool', 'Search');
INSERT IGNORE INTO vars VALUES ('hide_unposted_comments', 0, 'If 1, comments in stories that have been dropped or are still in the queue are not shown in the search results', 'bool', 'Search');
INSERT IGNORE INTO vars VALUES ('upload_max_file_size', 0, 'Maximum size of files permitted, in kilobytes', 'num', 'Uploads');
INSERT IGNORE INTO vars VALUES ('carry_comment_titles', 0, 'If 1, gives comments a default subject of "Re: <parent title>"', 'bool', 'Comments');
INSERT IGNORE INTO vars VALUES ('use_initial_rating', 0, 'If 1, gives all new comments an initial rating with zero votes.  Used to give unrated comments a rank when sorting by scores.  See anonymous_default_points and user_default_points for the defaults to use', 'bool', 'Comments');
INSERT IGNORE INTO vars VALUES ('anonymous_default_points', 2, 'If use_initial_rating is on, give all anonymous posters this rating to begin with', 'num', 'Comments');
INSERT IGNORE INTO vars VALUES ('user_default_points', 3, 'If use_initial_rating is on, give all registered posters this rating to begin with', 'num', 'Comments');
INSERT IGNORE INTO vars VALUES ('recent_topics_num', 0, 'The number of topic images to show if using the "recent topics" bar, as slashdot has.', 'num', 'Stories');
INSERT IGNORE INTO vars VALUES ('show_threshold', 0, 'Whether or not to show the post and drop thresholds in the moderation queue', 'bool', 'Stories');

UPDATE vars SET description='If 1, stories will be posted based on a metric including their current score and comment ratings.  To determine when this decision is made, see end_voting_threshold or auto_post_use_time' WHERE name='use_auto_post';
UPDATE vars SET description='Cache extra database info in memory?  (This is rather worthless unless db_cache_max is set stupidly high. Don''t bother enabling this.)' WHERE name='use_db_cache';
UPDATE vars SET description='If 1, your site will allow submission of ads.  Be sure to read the Scoop Administrator''s Guide for details of setting ads up properly.' WHERE name='use_ads';

DELETE FROM vars WHERE name='use_db_cache';
DELETE FROM vars WHERE name='use_new_scoring';
