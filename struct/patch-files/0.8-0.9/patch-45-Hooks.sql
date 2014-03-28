-- Create hook bindings table --
CREATE TABLE hooks (
  hook varchar(50) NOT NULL default '',
  func varchar(50) NOT NULL default '',
  is_box int(1) default '0',
  PRIMARY KEY (hook,func)
);

-- Create Hooks block containing the list of hooks available --
INSERT INTO blocks (bid,block,description,category) VALUES ('hooks', 'comment_new(sid, cid)\ncomment_rate(sid, cid, uid, rating)\nstory_hide(sid)\nstory_leave_editing(sid)\nstory_new(sid)\nstory_post(sid, where)\nstory_update(sid)\nstory_vote(sid, uid, vote, section_only)\nuser_new(nick)', 'A list of all the hooks available on the system. One hook per line, with the hook name followed by a comma-seperated list of arguments, in parenthesis.', 'block_programs');

-- Add Hooks admin tool --
INSERT INTO admin_tools(tool,pos,dispname,menuname,perm,func,is_box) VALUES
	('hooks', 17, 'Hooks', 'Hooks', 'edit_hooks', 'edit_hooks', 0);
UPDATE blocks SET block = CONCAT(block,',\nedit_hooks') WHERE bid = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms,',edit_hooks')
	WHERE perm_group_id = 'Superuser';

