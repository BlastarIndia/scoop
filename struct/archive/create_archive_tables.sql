
--
-- Table structure for table 'comments'
--

CREATE TABLE comments (
  sid varchar(30) NOT NULL default '',
  cid int(15) NOT NULL default '0',
  pid int(15) NOT NULL default '0',
  date datetime default NULL,
  rank int(1) default NULL,
  subject varchar(50) NOT NULL default '',
  comment text NOT NULL,
  pending int(1) default '0',
  uid int(1) NOT NULL default '-1',
  points decimal(4,2) default NULL,
  lastmod int(1) default '-1',
  sig_status int(1) default '1',
  sig varchar(160) default NULL,
  commentip varchar(16) default NULL,
  PRIMARY KEY  (sid,cid),
  KEY stuff (uid,pid),
  FULLTEXT KEY commentsearch_idx (subject,comment)
);


--
-- Table structure for table 'stories'
--

CREATE TABLE stories (
  sid varchar(20) NOT NULL default '',
  tid varchar(20) NOT NULL default '',
  aid varchar(30) NOT NULL default '',
  title varchar(100) default NULL,
  dept varchar(100) default NULL,
  time datetime NOT NULL default '0000-00-00 00:00:00',
  introtext text,
  bodytext text,
  writestatus int(1) NOT NULL default '0',
  hits int(1) NOT NULL default '0',
  section varchar(30) NOT NULL default '',
  displaystatus int(1) NOT NULL default '0',
  commentstatus int(1) default NULL,
  totalvotes int(11) NOT NULL default '0',
  score int(11) NOT NULL default '0',
  rating int(11) NOT NULL default '0',
  attached_poll varchar(20) default NULL,
  sent_email int(1) NOT NULL default '0',
  edit_category tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (sid),
  KEY section_idx (section,displaystatus),
  KEY displaystatus_idx (displaystatus),
  FULLTEXT KEY storysearch_idx (title,introtext,bodytext)
);


--
-- Table structure for table 'commentratings'
--

CREATE TABLE commentratings (
  uid int(1) NOT NULL default '0',
  rating int(11) NOT NULL default '0',
  cid int(15) NOT NULL default '0',
  sid varchar(30) NOT NULL default '',
  rating_time datetime default '0000-00-00 00:00:00',
  PRIMARY KEY  (sid,cid,uid)
);


--
-- Table structure for table 'storymoderate'
--

CREATE TABLE storymoderate (
  sid varchar(20) NOT NULL default '',
  uid int(11) NOT NULL default '0',
  time datetime default NULL,
  vote int(11) NOT NULL default '0',
  comment text,
  section_only enum('N','Y','X') NOT NULL default 'X',
  PRIMARY KEY  (sid,uid)
) ;


