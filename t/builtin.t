# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => 32;

no_diff;

run_tests();

__DATA__

=== TEST 1: set Server
--- config
    location /foo {
        echo hi;
        response_header_control set 'Server' 'Foo';
    }
--- request
    GET /foo
--- response_headers
Server: Foo
--- response_body
hi



=== TEST 2: clear Server
--- config
    location /foo {
        echo hi;
        response_header_control clear 'Server';
    }
--- request
    GET /foo
--- response_headers
! Server
--- response_body
hi



=== TEST 3: set Content-Type
--- config
    location /foo {
        default_type 'text/plain';
        response_header_control set 'Content-Type' 'text/css';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
Content-Type: text/css
--- response_body
hi



=== TEST 4: clear Content-Type
--- config
    location /foo {
        default_type 'text/plain';
        response_header_control clear 'Content-Type';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
! Content-Type
--- response_body
hi



=== TEST 5: set Content-Length
--- config
    location /len {
        response_header_control set 'Content-Length' '2';
        echo hello;
    }
--- request
    GET /len
--- response_headers
Content-Length: 2
--- response_body chop
he



=== TEST 6: set Content-Length twice (second wins)
--- config
    location /len {
        response_header_control set -n 'Content-Length' '2';
        response_header_control set 'Content-Length' '4';
        echo hello;
    }
--- request
    GET /len
--- response_headers
Content-Length: 4
--- response_body chop
hell



=== TEST 7: clear Content-Length
--- config
    location /len {
        response_header_control clear 'Content-Length';
        echo hello;
    }
--- request
    GET /len
--- response_headers
! Content-Length
--- response_body
hello



=== TEST 8: set Cache-Control
--- config
    location /foo {
        response_header_control set 'Cache-Control' 'no-cache';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Cache-Control: no-cache
--- response_body
ok



=== TEST 9: clear Cache-Control
--- config
    location /foo {
        response_header_control clear 'Cache-Control';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
! Cache-Control
--- response_body
ok



=== TEST 10: set Content-Encoding
--- config
    location /foo {
        response_header_control set 'Content-Encoding' 'gzip';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Content-Encoding: gzip
--- response_body
ok



=== TEST 11: clear Content-Encoding
--- config
    location /foo {
        response_header_control clear 'Content-Encoding';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
! Content-Encoding
--- response_body
ok



=== TEST 12: set Location
--- config
    location /foo {
        response_header_control set 'Location' '/new';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Location: /new
--- response_body
ok



=== TEST 13: set Expires
--- config
    location /foo {
        response_header_control set 'Expires' 'Thu, 01 Jan 2020 00:00:00 GMT';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Expires: Thu, 01 Jan 2020 00:00:00 GMT
--- response_body
ok



=== TEST 14: set Date
--- config
    location /foo {
        response_header_control set 'Date' 'Thu, 01 Jan 2020 00:00:00 GMT';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Date: Thu, 01 Jan 2020 00:00:00 GMT
--- response_body
ok



=== TEST 15: set Last-Modified
--- config
    location /foo {
        response_header_control set 'Last-Modified' 'Thu, 01 Jan 2020 00:00:00 GMT';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Last-Modified: Thu, 01 Jan 2020 00:00:00 GMT
--- response_body
ok



=== TEST 16: set Accept-Ranges
--- config
    location /foo {
        response_header_control set 'Accept-Ranges' 'bytes';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Accept-Ranges: bytes
--- response_body
ok
