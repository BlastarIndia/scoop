DELETE FROM vars WHERE name = 'db_cache_max';

INSERT INTO vars (name, value, description, type, category) VALUES ('max_cache_size', '5M', 'Maximum size for the memory cache in each process.  This is per-process and per-site, so two sites running on five processes will have 10 caches, each maxing out at this size', 'text', 'General');
INSERT INTO vars (name, value, description, type, category) VALUES ('cache_scan_interval', '2', 'How many requests to handle before scanning the cache to check its size. This can be fairly intensive, so on larger sites you should set this higher.', 'num', 'General');
