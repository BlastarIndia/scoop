INSERT INTO vars VALUES ('sendmail_program','/usr/sbin/sendmail','This is the path to your sendmail program.  This only matters if you set your SMTP setting in httpd.conf to \'-\', in which case this program will be used to send all site mail.','text','General');
INSERT INTO vars VALUES ('paranoid_logging',0,'If this var is turned on, a log of every request that comes to scoop will be kept in the error log, including time, date, IP of client, username, and all form parameters passed in.','bool','Security');

