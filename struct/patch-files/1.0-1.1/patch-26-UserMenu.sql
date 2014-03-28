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
-- WHERE:  boxid = 'userpref_menu'


/*!40000 ALTER TABLE `box` DISABLE KEYS */;
LOCK TABLES `box` WRITE;
INSERT IGNORE INTO `box` (`boxid`, `title`, `content`, `description`, `template`, `user_choose`) VALUES ('userpref_menu_file_pref','','my $edit = 0;\r\nmy $return = \'\';\r\nmy $nick = $S->param->{nick};\r\nmy $tool = $S->param->{tool} || \'info\';\r\nmy $admin_edit = \'\';\r\n\r\n# first, do we have permission to edit \r\n# this user\'s prefs?\r\n\r\nif ( $S->{UID} == $S->param->{uid} || $S->have_perm(\'edit_user\') ) {\r\n  $edit = 1;\r\n}\r\n\r\n$admin_edit = qq{[<A href=\"%%rootdir%%/user/$nick/prefs\">edit user</A>]} if ($S->have_perm(\'edit_user\'));\r\n\r\n# links to create\r\nmy $links = \"<P>$admin_edit ${nick}\'s \";\r\n\r\n# user info pages\r\nif ( $tool eq \'info\' ) {\r\n  $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick\">Info</A>};\r\n  $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/comments\">Comments</A>};\r\n  $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/stories\">Stories</A>};\r\n\r\n  if ( $S->{UI}->{VARS}->{use_diaries} ) {\r\n    $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/diary\">Diary</A>};\r\n  }\r\n\r\n  if ( $S->{UI}->{VARS}->{use_ratings} ) {\r\n    $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/ratings\">Ratings</A>};\r\n  }\r\nmy $udata = $S->user_data($S->param->{\'uid\'});\r\n#  if ( $S->{UI}->{VARS}->{allow_uploads} ) {\r\nif($S->{UI}->{VARS}->{allow_uploads} && (($S->have_perm(\'view_user_files\') && $S->have_perm(\'upload_user\', $udata->{\'perm_group\'})) || $S->have_perm(\'upload_admin\')) ) {\r\n    $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/files\">Files</A>};\r\n  }\r\n\r\n  if ( $S->{UI}->{VARS}->{use_ads} ) {\r\n    $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/ads\">Ads</A>};\r\n  }\r\n\r\n  $return = $links . \"</P>\";\r\n} elsif ( $edit && $tool eq \'prefs\' ) {\r\n  my %editlinks;\r\n  my ($rv, $sth) = $S->db_select({\r\n               WHAT => \'page, perm_edit\',\r\n               FROM => \'pref_items\',\r\n               GROUP_BY => \'page\'\r\n  });\r\n  while (my $item = $sth->fetchrow_hashref()) {\r\n     $editlinks{\"$item->{page}\"} = \"%%rootdir%%/user/$nick/prefs/$item->{page} $item->{perm_edit}\";\r\n  }\r\n  $sth->finish;\r\n  $links .= qq{\r\n     <A href=\"%%rootdir%%/user/$nick/prefs/Protected\">Email and Password</A>};\r\n\r\n  foreach my $item (sort {$b cmp $a} keys %editlinks) {\r\n    my $c = 0;\r\n    my ($rv2, $sth2) = $S->db_select({\r\n        WHAT => \'perm_edit\',\r\n        FROM => \'pref_items\',\r\n        WHERE => \"page = \'$item\'\"\r\n        });\r\n    while(my $i = $sth2->fetchrow_hashref()) {\r\n        $c++ if ($S->have_perm($i->{perm_edit}) || !$i->{perm_edit});\r\n        }\r\n    $sth2->finish;\r\n    $links .= ($c) ? qq{\r\n   <A href=\"$editlinks{$item}\">$item</A>} : \'\';\r\n  }\r\n  $return = $links . \"</P>\";\r\n}\r\n\r\nreturn $return;\r\n','navigation for user pref pages','empty_box',0);
UNLOCK TABLES;
/*!40000 ALTER TABLE `box` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

