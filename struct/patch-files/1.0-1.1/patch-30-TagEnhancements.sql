-- MySQL dump 10.9
--
-- Host: 10.250.27.101    Database: thebes
-- ------------------------------------------------------
-- Server version	4.1.11-Debian_3-log
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO,MYSQL323' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `box`
--
-- WHERE:  boxid in ('addtag', 'tag_listing', 'tag_page_order', 'tag_sort_change')


/*!40000 ALTER TABLE `box` DISABLE KEYS */;
LOCK TABLES `box` WRITE;
INSERT INTO `box` (`boxid`, `title`, `content`, `description`, `template`, `user_choose`) VALUES ('addtag','','my $sid = $S->cgi->param(\'sid\');\r\nmy $tagsave = $S->cgi->param(\'tagsave\');\r\nmy $newtags = $S->cgi->param(\'newtags\');\r\nreturn \"Error! No sid provided!\" if !$sid;\r\nmy $content;\r\n\r\n# I would, of course, prefer not to give\r\n# TUs extra privileges, but sometimes I guess\r\n# it must be done.\r\nmy $alltags;\r\nmy $subval;\r\nif ($S->have_perm(\'edit_story_tags\')){\r\n    $newtags ||= $S->get_tags_as_string($sid);\r\n    $alltags = $newtags;\r\n    $subval = \"Add/Edit\";\r\n    }\r\nelse {\r\n    $alltags = $S->get_tags_as_string($sid) . \", $newtags\";\r\n    $subval = \"Add\";\r\n    }\r\n#my $alltags = $S->get_tags_as_string($sid) . \", #$newtags\";\r\n$alltags =~ s/,$//;\r\n\r\n# if we\'re adding tags, add them and clear the new\r\n# tags var\r\nif($tagsave && $newtags){\r\n    $S->save_tags($sid, $alltags);\r\n    $content .= \"<p>Tags <b>$newtags</b> added.</p>\";\r\n    $newtags = \'\';\r\n    # and if we\'ve added tags, we\'re heading\r\n    # back to whence we came.\r\n    my $url = $S->{UI}->{VARS}->{site_url}   \r\n        . $S->{UI}->{VARS}->{rootdir} . \"/\"\r\n        . \"story/$sid\";\r\n    $S->{APACHE}->headers_out->{\'Location\'} = $url;\r\n    $S->{HEADERS_ONLY}=1;\r\n    }\r\nmy $curtags = $S->tag_display($sid);\r\n$content = \"Current $curtags\" . $content;\r\n\r\nmy $tagform = qq~\r\n<p><form name=\"addtag\" action=\"%%rootdir%%/addtag\" method=\"POST\">$subval Tags: (use commas to separate tags) <input type=\"hidden\" name=\"sid\" value=\"$sid\"><input type=\"text\" name=\"newtags\" size=\"30\" value=\"$newtags\"> <input type=\"submit\" name=\"tagsave\" value=\"$subval Tags\"></p></form></p><p>\r\n\'/\' characters are not allowed in tags, and will be converted to \'-\'.</p>\r\n~;\r\nreturn $content . $tagform;','','empty_box',0),('tag_listing','','my $sid = $S->cgi->param(\'sid\');\r\nmy $tags = $S->tag_display($sid);\r\nmy $content = \"$tags\";\r\n# if we can post comments, we can tag.\r\nif($S->have_perm(\'comment_post\')){\r\n    my $addlink = ($S->have_perm(\'edit_story_tags\')) ? qq~ :: <a href=\"/addtag/$sid\">Add/Edit Tags to this Story</a>~ : qq~ :: <a href=\"/addtag/$sid\">Add Tags to this Story</a>~;\r\n    $content .= $addlink;\r\n    }\r\nreturn $content;','','empty_box',0),('tag_page_order','','my $switch = $S->cgi->param(\'switch\');\r\n\r\nif($S->{UID} > 0){\r\n    $S->pref(\'tag_sort\', $switch); # nice and easy\r\n    }\r\nelse { # not so easy\r\n    $S->session(\'tag_sort\', $switch);\r\n    }\r\nmy $url = $S->{UI}->{VARS}->{site_url} . \r\n          $S->{UI}->{VARS}->{rootdir} . \"/\" \r\n          . \"tag\";\r\n\r\n		$S->{APACHE}->headers_out->{\'Location\'} = $url;\r\n$S->{HEADERS_ONLY}=1;\r\n\r\nreturn;','','empty_box',0),('tag_sort_change','','# change the default ordering for the \"All Tags\"\r\n# page\r\n# don\'t display if we\'re not looking at the \"All\r\n# Tags\" page, though.\r\nreturn if $S->cgi->param(\'tag\');\r\n\r\nmy $switchto = ($S->pref(\'tag_sort\') eq \'alpha\') ? \"count\" : \"alpha\";\r\n# and if we\'re not logged in, it\'s slightly\r\n# different\r\nif($S->{UID} < 0){\r\n    $switchto = ($S->session(\'tag_sort\') eq \'alpha\') ? \"count\" : \"alpha\";\r\n    }\r\nmy $ordering = ($switchto eq \'alpha\') ? \'Alphabetical\' : \'Popularity\';\r\nmy $link = qq~<a href=\"%%rootdir%%/tagsort/$switchto\">$ordering</a>.~;\r\n\r\n# a little complicated, but whatever\r\nmy $linktext = ($switchto eq \'alpha\') ? \"<br>Sort by: Popularity | $link\" : \"Sort by: $link | Alphabetical\";\r\n\r\nreturn $linktext;','','empty_box',0);
UNLOCK TABLES;
/*!40000 ALTER TABLE `box` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- MySQL dump 10.9
--
-- Host: 10.250.27.101    Database: thebes
-- ------------------------------------------------------
-- Server version	4.1.11-Debian_3-log
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO,MYSQL323' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `ops`
--
-- WHERE:  op in ('tagsort', 'addtag')


/*!40000 ALTER TABLE `ops` DISABLE KEYS */;
LOCK TABLES `ops` WRITE;
INSERT INTO `ops` (`op`, `template`, `func`, `is_box`, `enabled`, `perm`, `aliases`, `urltemplates`, `description`) VALUES ('addtag','default_template','addtag',1,1,'comment_post','','/sid{5}/',''),('tagsort','content_only_page_template','tag_page_order',1,1,'','','/switch/','');
UNLOCK TABLES;
/*!40000 ALTER TABLE `ops` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

