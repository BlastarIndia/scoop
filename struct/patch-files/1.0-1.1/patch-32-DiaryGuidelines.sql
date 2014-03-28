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
-- WHERE:  bid = 'diary_guidelines'


/*!40000 ALTER TABLE `blocks` DISABLE KEYS */;
LOCK TABLES `blocks` WRITE;
INSERT INTO `blocks` (`bid`, `block`, `aid`, `description`, `category`, `theme`, `language`) VALUES ('diary_guidelines','<P>Thank you for taking the time to submit a diary!</P>\r\n<P>There are no rules, you can post basically anything you want here. This is your spot to tell the rest of the community what\'s on your mind, or what\'s going on in your life, or just anything really.</P>\r\n<UL>\r\n<LI>Only the html tags listed are allowed in story text. No HTML is allowed in \"title\" or \"dept.\"</LI>\r\n<LI>You must preview at least once. Please read over your diary carefully.\r\n<LI>Unlike the rest of the site, this area is not subject to peer review, so don\'t fear the voting masses. Just tell us what\'s up with you.</LI>\r\n</UL>\r\n<P>Now post away!</P>','2','<P>This block is displayed above the story submission form. It should be self-contained HTML and should explain the site\'s submission guidelines. Keep in mind that the majority of people will at most skim this when going to post a story, so put the most important points up top.</P>','Stories','default','en');
UNLOCK TABLES;
/*!40000 ALTER TABLE `blocks` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

