# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (4 * blocks());

no_long_string();

run_tests();

__DATA__

=== TEST 1: clear Cookie (with existing cookies)
--- config
    location /t {
        request_header_control clear 'Cookie';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- more_headers
Cookie: foo=bar
Cookie: baz=blah
--- response_body
Cookie foo:
Cookie:



=== TEST 2: clear Cookie (without existing cookies)
--- config
    location /t {
        request_header_control clear 'Cookie';
        echo "Cookie foo: $cookie_foo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- response_body
Cookie foo:
Cookie:



=== TEST 3: set one custom Cookie
--- config
    location /t {
        request_header_control set 'Cookie' 'boo=123';
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- more_headers
Cookie: foo=bar
--- response_body
Cookie boo: 123
Cookie: boo=123



=== TEST 4: set custom Cookie without existing cookies
--- config
    location /t {
        request_header_control set 'Cookie' 'boo=123';
        echo "Cookie boo: $cookie_boo";
        echo "Cookie: $http_cookie";
    }
--- request
GET /t
--- response_body
Cookie boo: 123
Cookie: boo=123
