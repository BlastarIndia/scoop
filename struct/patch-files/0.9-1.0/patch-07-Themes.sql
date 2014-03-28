# block that chooses which themes to apply

INSERT INTO box VALUES ("theme_chooser", "", " ################################################\n# WARNING! This box is called so early in the  #\n# setup phase that screwing it up will require #\n# a trip directly to the database.  If you do  #\n# mess it up, follow the following procedure.  #\n#                                              #\n# First, hit the back button so you can read   #\n# these instructions.  That's the only part    #\n# you have to memorize.                        #\n# Second, go into the database and type the    #\n# following sql command (it's on 2 lines here) #\n#                                              #\n# UPDATE box SET content=\"return \\\"default\\\";\" #\n# WHERE boxid=\"theme_chooser\";                 #\n#                                              #\n# Don't forget the WHERE clause!               #\n# Then, figure out what went wrong, and fix it.#\n# You can save the box and it will overwrite   #\n# the simple 'return \"default\";' box that is   #\n# guaranteed to not cause errors.              #\n# If you didn't fix the problem, return to     #\n# step one and try again.                      #\n#                                              #\n# Please note that you won't have to change    #\n# this box unless you want to set a theme based#\n# on something other than section, user_agent, #\n# user group, and site_id. That's what the site#\n# controls in the category \"Themes\" are for.   #\n################################################\n\nmy $default_theme = $S->{UI}->{VARS}->{default_theme};\n\n# first, are we using themes at all:\nunless ( $S->{UI}->{VARS}->{use_themes} ) {\n    return $default_theme;\n}\n\n# returns a comma-separated list of themes to be \n# applied, in order.  Should always start with the \n# default theme.\n \n# set the values of the criteria we're testing for\nmy $siteid = $S->{CONFIG}->{site_id};\nmy $agent = $S->run_box(\"detect_agent\");\nmy $group = $S->{GID};\nmy $pref;\nif ( $S->{UI}->{VARS}->{allow_user_themes} ) {\n  if ( $S->{prefs}->{theme} ) {\n   $pref = $S->{prefs}->{theme};\n  } else {\n   $pref = \"\";\n  }\n}\n\n# section is a bit of a special case\nmy $section;\nif ( $S->param->{\"section\"} ) {\n  $section = $S->param->{\"section\"};\n} elsif ( $S->param->{\"sid\"} ) {\n  my $sid = $S->param->{\"sid\"};\n  my ($rv,$sth) = $S->db_select({\n         WHAT => 'section',\n           FROM => 'stories',\n          WHERE => qq@sid = \"$sid\"@,});\n  if ( $rv ) {\n    my $sect = $sth->fetchrow_hashref();\n    $section = $sect->{\"section\"};\n  } else {\n    $section = \"\";\n  }\n  $sth->finish;\n}\n\nmy @order = split( /,\s*/, $S->{UI}->{VARS}->{order} );\n\nmy $themelist = $default_theme;\n\nforeach my $criteria ( @order ) {\n  if ( $criteria eq \"section\" ) {\n   if ( $section ) {\n    my $th=$S->{UI}->{VARS}->{\"section_$section\"};\n    $themelist .= \",$th\" if $th;\n   }\n  } elsif ( $criteria eq \"siteid\" ) {\n    my $th = $S->{UI}->{VARS}->{\"siteid_$siteid\"};\n    $themelist .= \",$th\" if $th;\n  } elsif ( $criteria eq \"group\" ) {\n    my $th = $S->{UI}->{VARS}->{\"group_$group\"};\n    $themelist .= \",$th\" if $th;\n  } elsif ( $criteria eq \"agent\" ) {\n    my $th = \"\";\n    #FIXME: need to write box detect_agent\n  } elsif ( $criteria eq \"pref\" ) {\n    my $th = $pref;\n    $themelist .= \",$th\" if $th;\n  }\n}\n\nreturn $themelist;\n ", "chooses which themes should be applied, and in which order.  \'default\' should come first, as a complete theme; subsequent themes overwrite any blocks with the same name.", "blank_box", "0");
INSERT INTO box VALUES ("detect_agent", "", "#FIXME: add detection\n\nreturn \"\";", "detects user agent, returns a code string.", "blank_box", "0");

# vars

INSERT INTO vars VALUES ("order", "section", "Comma-separated list of criteria.  Determines which themes to apply in which order.  Possible values are section, siteid, agent, pref, and group.  Other selection criteria can be added by changing the box theme_chooser.  Later themes overwrite earlier ones in the case of any duplicate blocks, so take care when creating your themes.", "text", "Themes");
INSERT INTO vars VALUES ("allow_user_themes", "0", "Should users be allowed to choose which theme they want to use?", "bool", "Themes");
INSERT INTO vars VALUES ("user_themes", "", "comma-separated list of the themes the user is allowed to choose from, if allow_user_themes is enabled. This shows up in the display preferences.", "text", "Themes");

# blocks: theme greyscale for example purposes

INSERT INTO vars VALUES ("section_news", "greyscale", "apply the theme greyscale to news section only", "text", "Themes");

INSERT INTO blocks VALUES ("box_title_bg", "#999999", "1", "sidebar box titlebar background colour", "display", "greyscale", "en");
INSERT INTO blocks VALUES ("comment_head_bg", "#eeeeee", "1", "", "display", "greyscale", "en");
INSERT INTO blocks VALUES ("title_bgcolor", "#aaaaaa", "1", "", "display", "greyscale", "en");

# blocks: fix edit_one_block and edit_block
UPDATE blocks SET block = "<tr><td>%%norm_font%%Or edit a block directly:%%norm_font_end%%</td></tr>\n<tr><td><table cellspacing=\"2\" cellpadding=\"0\" width=\"100%\">\n<tr>\n	<td colspan=\"2\">%%norm_font%%<b>Delete:</b><input type=\"checkbox\" name=\"delete\" value=\"1\">%%norm_font_end%%</td>\n</tr>\n<tr>\n	<td>%%norm_font%%<b>Select Block:</b>%%norm_font_end%%</td>\n	<td>%%blockselect%%</td>\n</tr>\n<tr>\n	<td>%%norm_font%%<b>Select Categories:</b>%%norm_font_end%%</td>\n	<td>%%catselect%%</td>\n</tr>\n<tr>\n	<td>%%norm_font%%<b>Name:</b>%%norm_font_end%%</td>\n	<td><input type=\"text\" size=\"60\" name=\"name\" value=\"%%bid%%\"></td>\n</tr>\n<tr>\n	<td>%%norm_font%%<b>Theme:</b>%%norm_font_end%%</td>\n	<td><input type=\"text\" size=\"60\" name=\"block_theme\" value=\"%%theme%%\"><input type=\"hidden\" name=\"theme\" value=\"%%curr_theme%%\"></td>\n</tr>\n<tr>\n	<td>%%norm_font%%<b>New Category:</b>%%norm_font_end%%</td>\n	<td><input type=\"text\" size=\"60\" name=\"category\" value=\"\"><br>\n	%%norm_font%%<i>(seperate multiple categories with commas)</i>%%norm_font_end%%\n	</td>\n</tr>\n<tr>\n	<td colspan=\"2\">\n	%%norm_font%%<b>Value:</b>%%norm_font_end%%<br>\n	<textarea cols=\"60\" rows=\"20\" name=\"value\" wrap=\"soft\">%%value%%</textarea>\n	</td>\n</tr>\n<tr>\n	<td colspan=\"2\">\n	%%norm_font%%<b>Description:</b>%%norm_font_end%%<br>\n	<textarea cols=\"60\" rows=\"5\" name=\"description\"\n	wrap=\"soft\">%%description%%</textarea>\n	</td>\n</tr>\n</table></td></tr>\n" WHERE bid="edit_one_block";
UPDATE blocks SET block = '<form name=\"editblocks\" action=\"%%rootdir%%/admin/blocks/\" method=\"post\">\r\n<input type=\"hidden\" name=\"cat\" value=\"%%category%%\" />\r\n\r\n<table border=\"0\" cellpadding=\"2\" cellspacing=\"0\" width=\"100%\">\r\n<tr><td bgcolor=\"%%title_bgcolor%%\">%%title_font%%Blocks: %%category%%%%title_font_end%%</td></tr>\r\n<tr><td>%%norm_font%%%%update_msg%%%%norm_font_end%%</td></tr>\r\n<tr><td>%%norm_font%%%%theme_sel%%%%norm_font_end%%</td></tr>\r\n<tr><td>%%norm_font%%Choose a category to edit:%%norm_font_end%%</td></tr>\r\n<tr><td>\r\n	<table border=\"0\" cellpadding=\"0\" cellspacing=\"2\" width=\"100%\">%%catlist%%</table>\r\n</td></tr>\r\n<tr><td>%%norm_font%%<input type=\"submit\" name=\"save\" value=\"Save\"> <input type=\"submit\" name=\"edit\" value=\"Get\" />%%norm_font_end%%</td></tr>\r\n<tr><td>%%norm_font%%%%html_check%%%%norm_font_end%%</td></tr>\r\n<tr><td>\r\n	<table border=0 cellpadding=1 cellspacing=0 width=\"100%\">%%form_body%%</table>\r\n</td></tr>\r\n<tr><td>%%norm_font%%<input type=\"submit\" name=\"save\" value=\"Save\"> <input type=\"submit\" name=\"edit\" value=\"Get\" />%%norm_font_end%%</td></tr>\r\n</table>\r\n</form>\r\n' WHERE bid="edit_block";

# some var and block reorganisation

# make the field big enough to hold textareas...

ALTER TABLE vars CHANGE value value TEXT;

# get and reorganize the block_programs from blocks

INSERT INTO vars (name, value, description, category) SELECT bid,block,description,category from blocks WHERE category="block_programs";
UPDATE vars SET type="tarea" WHERE category="block_programs";
UPDATE vars SET category="Stories" WHERE name="autorelated";
UPDATE vars SET category="General" WHERE name="admin_alert";
UPDATE vars SET category="Ops" WHERE name="op_aliases";
UPDATE vars SET category="Ops" WHERE name="op_templates";
UPDATE vars SET category="Stories,Comments" WHERE name="all_html";
UPDATE vars SET category="Stories,Comments" WHERE name="allowed_html";
UPDATE vars SET category="Security" WHERE name="perms";
UPDATE vars SET category="General" WHERE name="hooks";

# and delete the blocks because they're no longer needed.

DELETE FROM blocks WHERE category="block_programs";
