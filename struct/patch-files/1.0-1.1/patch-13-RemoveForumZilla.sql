delete from box where boxid in ('fzdescribe', 'fzdisplay');
delete from blocks where bid in ('fzdisplay_template', 'fz_ad_url', 'fz_navigation_url', 'rss_template', 'rss_box');
delete from ops where op in ('fz', 'fzdisplay');
