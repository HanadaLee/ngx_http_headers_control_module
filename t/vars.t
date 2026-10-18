# vi:ft=

use lib 'lib';
use Test::Nginx::Socket;

plan 'no_plan';

no_diff;

run_tests();

__DATA__

=== TEST 1: variable in output header value
--- config
    location /foo {
        set $val 'hello, world';
        response_header_control set 'X-Foo' '$val';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
X-Foo: hello, world
--- response_body
hi



=== TEST 2: variable in input header value
--- config
    location /foo {
        set $val 'dog';
        request_header_control set 'Host' '$val';
        echo $host;
    }
--- request
    GET /foo
--- response_body
dog



=== TEST 3: header name remains literal
--- config
    location /foo {
        set $val 'hello';
        response_header_control set '$val' 'world';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
$val: world
! hello
--- response_body
hi
