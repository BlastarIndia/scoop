CREATE TABLE rdf_channels (
  rid smallint(6) NOT NULL auto_increment,
  rdf_link varchar(200) NOT NULL,
  link varchar(200),
  title varchar(60),
  description text,
  image_title varchar(40),
  image_url varchar(200),
  image_link varchar(200),
  form_title varchar(40),
  form_description tinytext,
  form_name varchar(20),
  form_link varchar(200),
  enabled int(1) default '1',
  PRIMARY KEY (rid)
);

CREATE TABLE rdf_items (
  rid smallint(6) NOT NULL,
  idx tinyint(4) NOT NULL,
  title varchar(100),
  link varchar(200),
  description tinytext,
  PRIMARY KEY (rid,idx)
);

INSERT INTO vars VALUES ('rdf_use_images','1','If set to\r\n1, then RDF images will be displayed. Otherwise, they won\'t','bool','RDF');
INSERT INTO vars VALUES ('rdf_use_forms','1','If set to\r\n1, then RDF textinputs will be displayed. Otherwise, they won\'t','bool','RDF');
INSERT INTO vars VALUES ('use_rdf_feeds','0','If set to 1, then RDF feeds are availible. Otherwise, they aren\'t','bool','RDF');

UPDATE perm_groups SET group_perms = CONCAT(group_perms,',rdf_admin') WHERE
perm_group_id = 'Superuser' OR perm_group_id = 'Admins';

INSERT INTO box VALUES ('rdf_feeds','External Feeds','return unless $S->{UI}->{VARS}->{use_rdf_feeds};\r\nmy $content;\r\nmy $channels = $S->rdf_channels();\r\nmy $user_feeds = $S->rdf_get_prefs();\r\n\r\nforeach my $c (@{$channels}) {\r\n   next unless $user_feeds->{ $c->{rid} } && $c->{title} && $c->{enabled};\r\n\r\n   if ($S->{UI}->{VARS}->{rdf_use_images} && $c->{image_url}) {\r\n      $content .= qq~<A HREF=\"$c->{image_link}\"><IMG SRC=\"$c->{image_url}\" ALT=\"$c->{image_title}\" BORDER=\"1\"></a><br>~;\r\n   } else {\r\n      $content .= qq~<B><A CLASS=\"light\" HREF=\"$c->{link}\">$c->{title}</a></b><BR>~;\r\n   }\r\n\r\n   my $items = $S->rdf_items($c->{rid});\r\n   foreach my $i (@{$items}) {\r\n      $content .= qq~%%dot%% <A CLASS=\"light\" HREF=\"$i->{link}\">$i->{title}</a><BR>~;\r\n   }\r\n\r\n   if ($S->{UI}->{VARS}->{rdf_use_forms} && $c->{form_link}) {\r\n      $content .= qq~<FORM ACTION=\"$c->{form_link}\" METHOD=\"GET\">$c->{form_title}: <INPUT TYPE=\"TEXT\" NAME=\"$c->{form_name}\"></form>~;\r\n   }\r\n\r\n   $content .= \"<BR>\";\r\n}\r\n\r\nreturn $content;\r\n','contains RDF feeds from other sites','box');

