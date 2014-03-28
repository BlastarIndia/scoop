-- Message shown in the comment space while loading the new content
INSERT INTO blocks (bid, block, description, category) VALUES ('dynamic_loading_message','%%norm_font%%<i>Loading...</i>%%norm_font_end%%', 'The message displayed to the user while a dynamic comment is loading.', 'site_html');
-- Change dynamic_template to fit the cleaned-up javascript code
UPDATE blocks SET block = '<HTML>\r\n<HEAD>\r\n<TITLE>%%sitename%% || %%subtitle%%</TITLE>\r\n%%dynamicmode_javascript%%\r\n</HEAD>\r\n<BODY onload=\"copyContent(%%mainpid%%,%%dynamicmode%%)\">\r\n%%CONTENT%%\r\n</BODY>\r\n</HTML>\r\n' WHERE bid = 'dynamic_template';
-- dynamicmode_iframe will be set to contain the magic iframe tag in dthreaded/
-- dminimal modes
UPDATE blocks SET block = CONCAT(block, '%%dynamicmode_iframe%%') WHERE bid = 'header';
-- Blocks for collapse/expand thread
INSERT INTO blocks (bid, block, description, category) VALUES ('dynamic_collapse_thread_link','<img src="/images/dyn_cola.gif" alt="--" title="Collapse Subthread" width="12" height="12" border="0">', 'Link to collapse a dynamic comment subthread.', 'site_html');
INSERT INTO blocks (bid, block, description, category) VALUES ('dynamic_expand_thread_link','<img src="/images/dyn_expa.gif" alt="++" title="Expand Subthread" width="12" height="12" border="0">', 'Link to expand a dynamic comment subthread.', 'site_html');

-- code using the block was added sometime ago, but the block was never added
-- to the db
INSERT IGNORE INTO blocks (bid, block, description, category) VALUES ('dynamic_js_tag', '<script type="text/javascript" src="%%rootdir%%/dynamic-comments.js"></script>', 'HTML used to add in dynamic comment support. Place |dynamicmode_javascript| into your templates and it will be replaced with this if dynamic comments are enabled.', 'site_html');
