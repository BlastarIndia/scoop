INSERT INTO vars(name,description,type,category) VALUES ('default_uid','If set, new accounts will have their preferences copied over from this UID upon confirmation.','num','General');

UPDATE box SET content = '$S = $S->reset_user;\r\n\r\nmy $logout_url = $S->{UI}->{VARS}->{logout_url}\r\n	|| ($S->{UI}->{VARS}->{rootdir} . \'/\');\r\n\r\n$S->{APACHE}->header_out( Location => $logout_url );\r\n\r\n# the following is probably unessesary, but just in case...\r\nreturn { content => qq{Redirecting to <a href="$logout_url">$logout_url</a>} }\r\n' WHERE boxid = 'logout_box';
