# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (4 * blocks());

no_long_string();

run_tests();

__DATA__

=== TEST 1: clear Connection header
--- config
    location /req-header {
        request_header_control clear 'Connection';
        echo "connection: $http_connection";
    }
--- request
GET /req-header
--- response_body
connection:



=== TEST 2: set Connection to close
--- config
    location /req-header {
        request_header_control set 'Connection' 'CLOSE';
        echo "connection: $http_connection";
    }
--- request
GET /req-header
--- response_body
connection: CLOSE



=== TEST 3: set Connection to keep-alive
--- config
    location /req-header {
        request_header_control set 'Connection' 'keep-alive';
        echo "connection: $http_connection";
    }
--- request
GET /req-header
--- response_body
connection: keep-alive



=== TEST 4: set Connection to unknown value
--- config
    location /req-header {
        request_header_control set 'Connection' 'bad';
        echo "connection: $http_connection";
    }
--- request
GET /req-header
--- response_body
connection: bad
