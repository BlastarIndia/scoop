ALTER TABLE users DROP COLUMN maillist;
ALTER TABLE users ADD COLUMN pass_confirm VARCHAR(12);
ALTER TABLE users ADD COLUMN pass_sent_at DATETIME;

INSERT INTO vars (name, value, description, type, category) VALUES ('confirms_valid_for', '120', 'Length of time, in minutes, that confirm strings for new passwords should remain valid.', 'num', 'General');

UPDATE blocks SET block = CONCAT(block, ',\nconfirmpass=/nick/key/') WHERE bid = 'op_templates';
