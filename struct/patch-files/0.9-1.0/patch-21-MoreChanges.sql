UPDATE blocks SET block = '<p>You are not currently a paid member. Why not <a href="%%rootdir%%/subscribe">become one</a>?</p>' WHERE bid = 'subscribe';
DELETE FROM blocks WHERE bid = 'pendingstory_bg';
DELETE FROM blocks WHERE bid = 'poll_box' OR bid = 'poll_guidelines' OR bid = 'preview_text_ad_template' OR bid = 'renew_confirm_message';
INSERT INTO blocks (bid, block, description, category, theme, language) VALUES ('rating_format', '(<A HREF="%%rootdir%%/comments/%%sid%%/%%cid%%?mode=alone;showrate=1#%%cid%%">%%score%% / %%num_ratings%%</A>)', 'The rating part of a comment for inclusion into the comment block.', 'site_html', 'default', 'en');
INSERT INTO blocks (bid, block, description, category, theme, language) VALUES ('donate_email_pledge', 'Thank you for your donation. Please remember to send $%%AMOUNT%% to our mailing address.', 'Email sent to confirm a pledge to donate. Should probably remind the person to actually send their money.', 'email', 'default', 'en');
INSERT INTO blocks (bid, block, description, category, theme, language) VALUES ('donate_email_success', 'Thank you for your donation of $%%AMOUNT%%.', 'Email sent to confirm that a donation was recieved.', 'email', 'default', 'en');
INSERT INTO blocks (bid, block, description, category, theme, language) VALUES ('next_previous_links', '', 'If filled in, can be used to replace the Next and Previous links on the front and section pages. The special keys PREVIOUS_LINK and NEXT_LINK will be filled with the appropriate relative URLs. If this block is left empty, then the default code will be used instead.', 'site_html', 'default', 'en');

UPDATE vars SET value = CONCAT('', value, '\ncomment_toggle(sid,cid,tool)\nfile_upload(path)\nuser_confirm(nick)') WHERE name = 'hooks';
INSERT INTO vars (name, value, description, type, category) VALUES ('paypal_business_id', 'paypal@mysite.org', 'The business/paypal id that''s used for recieving paypal payments, such as through ad_pay_paypal or subpay_paypal.', 'text', 'Advertising,General');

UPDATE ops SET urltemplates = '/tool/' WHERE op = 'newuser';

ALTER TABLE storymoderate DROP COLUMN comment;

-- convert old style box ops to new ones
UPDATE ops SET func = 'buyimpressions_box', is_box = 1, template = 'default_template' WHERE op = 'ads';
DELETE FROM blocks WHERE bid = 'buyimpressions_template';

UPDATE ops SET func = 'fzdisplay', is_box = 1 WHERE op = 'fzdisplay';
UPDATE blocks SET block = '<html>\r\n<head><title>%%slogan%%</title></head>\r\n<body bgcolor="#EEEEEE">\r\n<table width="80%" align="center" cellpadding=0 cellspacing=0 bgcolor="#000000" border=0>\r\n<tr><td>\r\n<table width="100%" align="center" cellpadding=10 cellspacing=0 bgcolor="#ffffff" border=0>\r\n<tr><td>\r\n%%CONTENT%%</center>\r\n</td></tr>\r\n</table>\r\n</td></tr>\r\n</table>\r\n</body>\r\n</html>' WHERE bid = 'fzdisplay_template';

UPDATE ops SET func = 'renewad_box', is_box = 1, template = 'default_template' WHERE op = 'renew';
DELETE FROM blocks WHERE bid = 'renewad_template';

UPDATE ops SET func = 'submit_rdf', is_box = 1, template = 'default_template' WHERE op = 'submitrdf';
DELETE FROM blocks WHERE bid = 'submitrdf_template';
