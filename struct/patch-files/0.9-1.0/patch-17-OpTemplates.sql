ALTER TABLE `ops` ADD `aliases` VARCHAR( 255 ) NOT NULL AFTER `perm` ;
ALTER TABLE `ops` ADD `urltemplates` TEXT NOT NULL AFTER `aliases` ;
INSERT INTO `vars` VALUES ('main_op_eval', '0', 'Enable evaluation of URL/OP templates for URLs having no pathinfo. Useful for running an EVAL block for the main OP, to alter behavior based on arbitrary request info.', 'bool', 'Ops');
INSERT INTO `vars` VALUES ('use_host_parse', '0', 'URL (op) Templates can be constructed that make use of a special array @host, which contains fragments of the hostname used in the HTTP request. $host[0] contains the FQDN. the other array elements contain 1 or more elements of the hostname, split from left to right. These tokens can be used to set param values within URL (op) Templates.\r\nExample for \'main\' OP:   /op=section/page=$host[1]/\r\ncauses display of section based on first host fragment', 'bool', 'Ops');


