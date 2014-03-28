INSERT INTO box (boxid,title,content,description,template,user_choose) VALUES ('startpage_validation','','if ( $S->{SECTION_DATA}->{$ARGS[1]} || $ARGS[1] eq \'__main__\' || $ARGS[1] eq \'__all__\' ) {\n  return '';\n} else {\n  return "Start Page not valid<BR>";\n}','validates the start page pref','empty_box','0');
UPDATE pref_items set regex='BOX,startpage_validation' WHERE prefname='start_page';

