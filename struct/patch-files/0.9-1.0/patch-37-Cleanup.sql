-- a few fixes to block categories
UPDATE blocks SET category='Fonts' WHERE bid='error_font';
UPDATE blocks SET category='Fonts' WHERE bid='error_font_end';
UPDATE blocks SET category='Admin Pages' WHERE bid='edit_macro';
UPDATE blocks SET category='Admin Pages' WHERE bid='edit_one_macro';
UPDATE blocks SET category='Admin Pages' WHERE bid='macro_category_list';
UPDATE blocks SET category='Ads' WHERE bid='ad_submitted_message';
UPDATE blocks SET category='Ads' WHERE bid='ad_renewed_message';
UPDATE blocks SET category='Ads' WHERE bid='ad_pay_cc_msg';
UPDATE blocks SET category='Ads' WHERE bid='ad_pay_paypal_msg';
UPDATE blocks SET category='Ads' WHERE bid='ad_free_msg';
UPDATE blocks SET category='Ads,Subscriptions' WHERE bid='sub_paypal_finished';
