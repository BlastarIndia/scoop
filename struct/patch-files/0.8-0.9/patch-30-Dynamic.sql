INSERT INTO blocks VALUES ('dynamic_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%sitename%% || %%subtitle%%</TITLE>\r\n<SCRIPT TYPE=\"text/javascript\" SRC=\"/dynamic-comments.js\"></SCRIPT>\r\n</HEAD>\r\n<BODY bgcolor=\"#FFFFFF\" text=\"#000000\" link=\"#006699\" vlink=\"#003366\" onload=\"copyContent(%%mainpid%%,%%dynamicmode%%,\'%%dynamic_expand_link%%\',\'%%dynamic_collapse_link%%\')\">\r\n%%CONTENT%%\r\n</BODY>\r\n</HTML>\r\n',NULL,NULL);
INSERT INTO blocks VALUES ('dynamic_expand_link','<img src=%%imagedir%%/dyn_exp.gif width=12 height=16 ALT=+ border=0>',NULL,NULL);
INSERT INTO blocks VALUES ('dynamic_collapse_link','<img src=%%imagedir%%/dyn_col.gif width=12 height=16 ALT=- border=0>',NULL,NULL);
UPDATE blocks SET block = CONCAT(block, ",\r\ndynamic") WHERE bid = 'opcodes';
INSERT INTO templates(template_id,opcode) VALUES ('dynamic_template','dynamic');
INSERT INTO vars(name,value,description,type,category) VALUES ('allow_dynamic_comment_mode','0','Turn this on to allow users to set the "Dynamic" comment threading mode (which requires Javascript and at least a 5.x-generation browser)','bool','Comments');
