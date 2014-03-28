UPDATE blocks SET block=REPLACE(block,"$text","%%text%%") WHERE bid in ("delimiter_dyn_itemstart","delimiter_dyn_itemend");
UPDATE blocks SET block=REPLACE(block,"$class","%%class%%") WHERE bid in ("delimiter_dyn_itemstart","delimiter_dyn_itemend");

UPDATE blocks SET block=INSERT(block,LOCATE('ACTION="%%rootdir%%/"',block),21,'ACTION=""') WHERE bid='login_box';

