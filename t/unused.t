# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 + 2);

log_level("warn");
no_diff;

run_tests();

__DATA__

=== TEST 1: output filter used when response_header_control present
--- config
    location /foo {
        echo hi;
        response_header_control set 'Foo' 'bar';
    }
--- request
    GET /foo
--- response_headers
Foo: bar
--- response_body
hi
--- error_log
headers control header filter
--- no_error_log
[error]
--- log_level: debug



=== TEST 2: output filter unused when no directives
--- config
    location /foo {
        echo hi;
    }
--- request
    GET /foo
--- response_body
hi
--- no_error_log
headers control header filter
[error]
--- log_level: debug



=== TEST 3: output filter unused with request_header_control only
--- config
    location /foo {
        request_header_control set 'Foo' 'bar';
        echo hi;
    }
--- request
    GET /foo
--- response_body
hi
--- no_error_log
headers control header filter
[error]
--- log_level: debug



=== TEST 4: rewrite handler used when request_header_control present
--- config
    location /foo {
        request_header_control set 'Foo' 'bar';
        echo hi;
    }
--- request
    GET /foo
--- response_body
hi
--- error_log
headers control rewrite handler
--- no_error_log
[error]
--- log_level: debug



=== TEST 5: rewrite handler unused when no input directives
--- config
    location /foo {
        echo hi;
    }
--- request
    GET /foo
--- response_body
hi
--- no_error_log
headers control rewrite handler
[error]
--- log_level: debug



=== TEST 6: rewrite handler unused with output directives only
--- config
    location /foo {
        echo hi;
        response_header_control set 'Foo' 'bar';
    }
--- request
    GET /foo
--- response_headers
Foo: bar
--- response_body
hi
--- no_error_log
headers control rewrite handler
[error]
--- log_level: debug
