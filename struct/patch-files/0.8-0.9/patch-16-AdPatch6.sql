UPDATE blocks SET block = CONCAT(block, ",\nhotlist") WHERE bid = 'opcodes';
ALTER TABLE ad_info add column judger int(11); 

