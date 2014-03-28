-- Change users' existing dynamic_to prefs to dthreaded_to
UPDATE userprefs SET prefname = 'dthreaded_to' WHERE prefname = 'dynamic_to';
-- Add dynamic_loading_link block for the state between expanding and collapsing
INSERT INTO blocks VALUES ('dynamic_loading_link','<img src=%%imagedir%%/dyn_wait.gif width=12 height=16 ALT=x border=0>',NULL,NULL);

