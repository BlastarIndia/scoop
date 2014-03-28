CREATE TABLE ad_payments (
	ad_id       int(11) NOT NULL,
	order_id    varchar(50) NOT NULL,
	cost        decimal(7,2) NOT NULL,
	pay_type    varchar(10) NOT NULL,
	auth_date   date NOT NULL,
	final_date  date,
	paid        int(1),
	PRIMARY KEY (ad_id,order_id)
);


INSERT INTO vars (name,value,description,type,category) VALUES ('min_ad_prepay_amount','12.00','This is the minimum amount of money that scoop will let people prepay','text','Advertising');
INSERT INTO vars (name,value,description,type,category) VALUES ('mail_ad_reminders','0','If turned on then Scoop will mail reminders to advertisers when their ad has \'mail_ad_reminder_on\' impressions left.','bool','Advertising');
INSERT INTO vars (name,value,description,type,category) VALUES ('mail_ad_reminder_on','100','If \'mail_ad_reminders\' is on, then when there are this many impressions left Scoop will send a reminder to the advertiser about their ad.','num','Advertising');
INSERT INTO vars (name,value,description,type,category) VALUES ('mail_ad_finished_reminder','0','If turned on then Scoop will mail the advertisers letting them know when their ad has finished its campaign.','bool','Advertising');
INSERT INTO vars (name,value,description,type,category) VALUES ('activate_upon_approve','1','If you are not getting payments via CC or paypal or whatever, set this to 1.  That way, when you activate an ad, it will automatically get in the rotation, instead of waiting for the ad_cron script to activate it.','bool','Advertising');

INSERT INTO blocks (bid,block) VALUES ('mail_ad_almost_done_msg','The ad that you submitted to %%sitename%% has is almost finished wth its campaign. You only have %%VIEWS_LEFT%% impressions left before its gone.  If you would like to not receive these reminders, please reply and let us know.

Advertisement details:
Title: %%TITLE%%
Text1: %%TEXT1%%
URL: %%URL%%

If you have received this message in error, please reply and let us know.

-%%sitename%%
%%local_email%%
');

INSERT INTO blocks (bid,block) VALUES ('mail_ad_done_msg','The ad that you submitted to %%sitename%% has finished its campaign.  Thank you for advertising on our site, we look forward to doing business with you again.

Advertisement details:
Title: %%TITLE%%
Text1: %%TEXT1%%
URL: %%URL%%

If you have received this message in error, please reply and let us know.

-%%sitename%%
%%local_email%%
');

INSERT INTO blocks (bid,block) VALUES ('buy_ad_impression_message','From here you can pre-pay for ad impressions.  Once you have prepaid impressions on your account, you can distribute them to any ad you have submitted, from the <a href="%%rootdir%%/ads/dist">distribution</a> page.');
INSERT INTO blocks (bid,block) VALUES ('confirm_purchase_impressions','If you\'re sure that you want to buy this many impressions, click "Purchase" below, and proceed to the payment page.  If you need to make a change, change the number and hit confirm again.');

ALTER TABLE ad_info ADD COLUMN approved int(1);
ALTER TABLE ad_info ADD COLUMN cash_cache decimal(7,2);
ALTER TABLE ad_info CHANGE COLUMN sponser sponsor int(11);

UPDATE ad_info set approved = 1 where judged=1 and active=1 and approved is NULL;
