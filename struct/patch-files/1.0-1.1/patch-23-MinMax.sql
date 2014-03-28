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
-- Dumping data for table `vars`
--
-- WHERE:  name IN ('max_title_len', 'min_intro_words', 'min_intro_chars')


/*!40000 ALTER TABLE `vars` DISABLE KEYS */;
LOCK TABLES `vars` WRITE;
INSERT INTO `vars` (`name`, `value`, `description`, `type`, `category`) VALUES ('max_title_len','100','The maximum length in characters a title can be.','num','Stories'),('min_intro_chars','0','The minimum number of characters that can be used in a story. The default is 0, which disables use of this. It works much the same as min_intro_words. Only one of the two should be used.','num','Stories'),('min_intro_words','300','The minimum number of words that can be used in a story. The default is 300. 0 disables this feature. It works much the same as min_intro_chars. Only one of the two should be used.','num','Stories');
UNLOCK TABLES;
/*!40000 ALTER TABLE `vars` ENABLE KEYS */;

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
-- Dumping data for table `blocks`
--
-- WHERE:  bid in ('max_intro_warning', 'min_intro_warning')


/*!40000 ALTER TABLE `blocks` DISABLE KEYS */;
LOCK TABLES `blocks` WRITE;
INSERT INTO `blocks` (`bid`, `block`, `aid`, `description`, `category`, `theme`, `language`) VALUES ('max_intro_warning','<p>Hey, you didn\'t read the rules! You have too much text in the introtext box. Please edit your submission accordingly and use the bodytext box for the bulk of your diary.</p>','1','A warning message for users who have too much stuff in their intro.','Stories','default','en'),('min_intro_warning','<p>Sorry, your story/diary is not long enough. Please edit it so it has more content.</p>\r\n\r\nThe minumum is __MININTRO__ __UNIT__.','1','','Stories','default','en');
UNLOCK TABLES;
/*!40000 ALTER TABLE `blocks` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

UPDATE vars SET value = CONCAT(value,',\nevade_intro_limits') WHERE name = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms,',evade_intro_limits') WHERE perm_group_id IN ('Superuser','Admins','Editors');
