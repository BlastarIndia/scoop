UPDATE blocks SET block = CONCAT('main,\r\n', block) WHERE bid = 'opcodes';
INSERT INTO templates VALUES ('index_template','main');

INSERT INTO blocks (bid, block) VALUES ('perms','edit_perms,\nshow_perms,\nedit_user,\nedit_special,\nedit_boxes,\nedit_vars,\nlist_polls,\nedit_topics,\nedit_polls,\nedit_sections,\nstory_admin,\nstory_post,\nstory_list,\ncomment_post,\ncomment_delete,\ncomment_rate,\nmoderate,\nattach_poll,\npoll_vote,\npoll_post_comments,\npoll_read_comments,\nview_polls,\nedit_groups,\nedit_templates,\nsuper_mojo,\nrdf_admin,\nsubmit_rdf,\ncron_admin,\nad_admin,\nedit_blocks,\nsubmit_ad\n');

ALTER TABLE cron ADD COLUMN is_box INT(1) DEFAULT 0;
DELETE FROM cron WHERE name = 'storyreap';
