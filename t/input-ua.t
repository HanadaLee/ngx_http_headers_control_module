# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (4 * blocks());

no_long_string();

run_tests();

__DATA__

=== TEST 1: clear User-Agent
--- config
    location /t {
        request_header_control clear 'User-Agent';
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /t
--- more_headers
User-Agent: Mozilla/5.0 (compatible; MSIE 7.0)
--- response_body
User-Agent:



=== TEST 2: set custom User-Agent
--- config
    location /t {
        request_header_control set 'User-Agent' 'Mozilla/5.0 Custom/1.0';
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /t
--- more_headers
User-Agent: original
--- response_body
User-Agent: Mozilla/5.0 Custom/1.0



=== TEST 3: rewrite User-Agent (exists)
--- config
    location /t {
        request_header_control rewrite 'User-Agent' 'Rewritten/1.0';
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /t
--- more_headers
User-Agent: Mozilla/5.0
--- response_body
User-Agent: Rewritten/1.0



=== TEST 4: rewrite User-Agent (absent)
--- config
    location /t {
        request_header_control rewrite 'User-Agent' 'No-Op';
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /t
--- response_body
User-Agent:
