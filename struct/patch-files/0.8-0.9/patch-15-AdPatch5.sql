ALTER TABLE ad_info add column purchase_size int(11) default 0;
ALTER TABLE ad_info add column purchase_price decimal(7,2) default 0;

ALTER TABLE ad_types add column max_purchase_size int(7) default 100000;
UPDATE ad_types set max_purchase_size = 100000 where max_purchase_size is NULL;

INSERT INTO vars VALUES('log_ip_for_ads', '0', 'If this is on it logs the ip of each ad view or clickthrough in the ad_logs table','bool','Advertising');

CREATE TABLE ad_log (
	req_num    bigint NOT NULL PRIMARY KEY auto_increment,
	req_time   int(11) NOT NULL,
	requestor  int(11) NOT NULL,
	request_ip varchar(16) NOT NULL,
	ad_id      int(11) NOT NULL,
	req_type   varchar(20) NOT NULL
);
