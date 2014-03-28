ALTER TABLE ad_info add column paid int(1);

UPDATE blocks set block = CONCAT(block, ',\nadinfo') WHERE bid='opcodes';
UPDATE blocks set block = CONCAT(block, ',\nadinfo=/ad_id/,') WHERE bid='op_templates';

INSERT INTO templates VALUES ('default_template','adinfo');

