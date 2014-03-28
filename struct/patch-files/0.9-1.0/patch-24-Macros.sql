INSERT INTO admin_tools VALUES ('macros',20,'Macros','Macros','edit_macros','edit_macros',0);
 
INSERT INTO blocks VALUES ('edit_macro','<form name=\"editmacros\" action=\"%%rootdir%%/admin/macros/\" method=\"post\">\r\n<input type=\"hidden\" name=\"cat\" value=\"%%category%%\" />\r\n\r\n<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\">\r\n<tr><td bgcolor=\"%%title_bgcolor%%\">%%title_font%%Macros: %%category%%%%title_font_end%%</td></tr>\r\n<tr><td>%%norm_font%%%%update_msg%%%%norm_font_end%%</td></tr>\r\n<tr><td> </td></tr>\r\n<tr><td>%%norm_font%%Choose a category to edit:%%norm_font_end%%</td></tr>\r\n<tr><td>\r\n	<table border=\"0\" cellpadding=\"0\" cellspacing=\"2\" width=\"100%\">%%catlist%%</table>\r\n</td></tr>\r\n<tr><td>%%norm_font%%<input type=\"submit\" name=\"save\" value=\"Save\" /> <input type=\"submit\" name=\"edit\" value=\"Get\" />%%norm_font_end%%</td></tr>\r\n<tr><td><table border=\"0\" cellpadding=\"2\" cellspacing=\"0\" width=\"100%\">%%form_body%%</table></td></tr>\r\n<tr><td>%%norm_font%%<input type=\"submit\" name=\"save\" value=\"Save\" /> <input type=\"submit\" name=\"edit\" value=\"Get\" />%%norm_font_end%%</td></tr>\r\n</table>\r\n</form>\r\n',NULL,'The main edit macro page.  The special var \"form_body\" is either the single-var edit form, or the category table, depending on which view you\'re using.','admin_pages','default','en');

INSERT INTO blocks VALUES ('edit_one_macro','<tr><td>%%norm_font%%Or edit a macro directly:%%norm_font_end%%</td></tr>\r\n<tr><td><table cellspacing=\"2\" cellpadding=\"0\" width=\"100%\">\r\n	<tr>\r\n		<td colspan=\"2\">%%norm_font%%<b>Delete:</b><input type=\"checkbox\" name=\"delete\" value=\"1\" />%%norm_font_end%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Select Macro:</b>%%norm_font_end%%</td>\r\n		<td>%%macroselect%%</td>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Select Categories:</b>%%norm_font_end%%</td>\r\n		<td>%%catselect%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Name:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"text\" size=\"60\" name=\"name\" value=\"%%name%%\" /></td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>New Category:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"text\" size=\"60\" name=\"category\" value=\"\"><br />\r\n			%%norm_font%%<i>(seperate multiple categories with commas)</i>%%norm_font_end%%\r\n		</td>\r\n	</tr>\r\n	<tr>\r\n		<td colspan=\"2\">\r\n			%%norm_font%%<b>Value:</b>%%norm_font_end%%<br />\r\n			<textarea cols=\"60\" rows=\"6\" name=\"value\" wrap=\"soft\">%%value%%</textarea>\r\n		</td>\r\n	</tr>\r\n	<tr>\r\n		<td colspan=\"2\">\r\n			%%norm_font%%<b>Description:</b>%%norm_font_end%%<br />\r\n			<textarea cols=\"60\" rows=\"3\" name=\"description\" wrap=\"soft\">%%description%%</textarea>\r\n		</td>\r\n	</tr>\r\n</table></td></tr>\r\n',NULL,'','admin_pages','default','en');

INSERT INTO blocks VALUES ('macro_category_list','<tr>\r\n	<td>%%norm_font%%<a href=\"%%rootdir%%/admin/macros/%%item_url%%\">%%item%%</a>%%norm_font_end%%</td>\r\n	<td>%%norm_font%%<a href=\"%%rootdir%%/admin/macros/%%item_url%%\">%%item%%</a>%%norm_font_end%%</td>\r\n	<td>%%norm_font%%<a href=\"%%rootdir%%/admin/macros/%%item_url%%\">%%item%%</a>%%norm_font_end%%</td>\r\n</tr>\r\n',NULL,'One line of the macro category list.  Usually one table row.','admin_pages','default','en');

INSERT INTO vars VALUES ('use_macros','0','Set to 1 to enable the use of macros in stories and comments.','bool','Macros');
INSERT INTO vars VALUES ('macro_render_on_save','0','Set to 1 to cause macros to render when saved; if 0, macros remain as raw macro text in stories and comments until archived','bool','Macros');
INSERT INTO vars VALUES ('macro_render_verbose','0','Set to 1 to render macros verbosely, with HTML comments as delimiters and original macro text preserved in comment (for post-processing)','bool','Macros');

--
-- Table structure for table 'macros'
--

CREATE TABLE macros (
  name varchar(32) NOT NULL default '',
  value text,
  description text,
  category varchar(128) NOT NULL default '',
  PRIMARY KEY  (name)
);

--
-- Dumping data for table 'macros'
--


INSERT INTO macros VALUES ('macro_test','<span style="color: red">The macro engine is active!</span>','A test macro - if you can see it, it\'s working.','General');

