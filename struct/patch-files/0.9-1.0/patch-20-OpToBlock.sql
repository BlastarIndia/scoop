INSERT INTO blocks VALUES ('edit_ops','<form action=\"%%rootdir%%/admin/ops\" method=\"POST\">\r\n<table width=\"100%\" border=\"0\" cellpadding=\"2\" cellspacing=\"0\">\r\n	<tr bgcolor=\"%%title_bgcolor%%\">\r\n		<td colspan=\"2\">%%title_font%%Edit Ops%%title_font_end%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td colspan=\"2\">%%title_font%%<font color=\"#ff0000\">%%msg%%</font>%%title_font_end%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td align=\"right\">\r\n			<input type=\"submit\" name=\"get\" value=\"Get Op\" />\r\n		</td>\r\n		<td>%%op_list%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Op:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"text\" name=\"opcode\" value=\"%%opcode%%\" /></td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Template:</b>%%norm_font_end%%</td>\r\n		<td>%%tmpl_list%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Function:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"text\" name=\"func\" value=\"%%func%%\" />%%edit_box%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>&nbsp;</td>\r\n		<td>%%norm_font%%\r\n			<input type=\"checkbox\" name=\"is_box\" value=\"1\" %%is_box_checked%% /> Function is a box%%norm_font_end%%\r\n		</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Permission:</b>%%norm_font_end%%</td>\r\n		<td>%%perm_list%%</td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>Enabled:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"checkbox\" name=\"enabled\" value=\"1\" %%enabled_checked%% /></td>\r\n	</tr>\r\n	<tr>\r\n		<td>%%norm_font%%<b>OP Aliases:</b>%%norm_font_end%%</td>\r\n		<td><input type=\"text\" name=\"aliases\" value=\"%%aliases%%\" size=\"40\" /></td>\r\n	</tr>\r\n	<tr>\r\n		<td valign=\"top\">%%norm_font%%<b>URL Templates:</b>%%norm_font_end%%</td>\r\n		<td><textarea cols=\"40\" rows=\"10\" name=\"urltemplates\" wrap=\"no\">%%urltemplates%%</textarea></td>\r\n	</tr>\r\n	<tr>\r\n		<td valign=\"top\">%%norm_font%%<b>Description:</b>%%norm_font_end%%</td>\r\n		<td><textarea cols=\"40\" rows=\"3\" name=\"desc\" wrap=\"soft\">%%desc%%</textarea></td>\r\n	</tr>\r\n	%%delete_check%%\r\n	<tr>\r\n		<td>&nbsp;</td>\r\n		<td>\r\n			<input type=\"submit\" name=\"save\" value=\"Write Op\" /> \r\n			<input type=\"reset\" value=\"Reset\" />\r\n		</td>\r\n	</tr>\r\n</table>\r\n</form>','1','edit ops admin tool','site_html','default','en');

