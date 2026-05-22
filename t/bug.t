# vi:filetype=

use Test::Nginx::Socket;

repeat_each(2);

plan tests => 24 * repeat_each();

no_diff;

run_tests();

__DATA__

=== TEST 1: clear builtin Last-Modified
--- config
    location /foo {
        echo hi;
        response_header_control clear 'Last-Modified';
    }
--- request
    GET /foo
--- response_headers
! Last-Modified
--- response_body
hi



=== TEST 2: variables in header value
--- config
    location /foo {
        set $rfrom 1;
        set $rto 3;
        request_header_control set 'Range' 'bytes=$rfrom - $rto';
    }
--- request
GET /foo
--- error_code: 206
--- response_body chomp
htm



=== TEST 3: empty variable as header value
--- config
    location /foo {
        response_header_control set 'X-Foo' '$arg_foo';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
hi



=== TEST 4: clear Accept-Ranges
--- config
    location /foo {
        echo hi;
        response_header_control clear 'Accept-Ranges';
    }
--- request
    GET /foo
--- response_headers
! Accept-Ranges
--- response_body
hi



=== TEST 5: clear then set
--- config
    location /foo {
        response_header_control clear 'Foo';
        response_header_control set 'Foo' 'a';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
Foo: a
--- response_body
hi



=== TEST 6: set then clear then set again
--- config
    location /foo {
        response_header_control set 'Foo' 'a';
        response_header_control clear 'Foo';
        response_header_control set 'Foo' 'b';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
Foo: b
--- response_body
hi



=== TEST 7: override Content-Type charset
--- config
    location /backend {
        default_type "text/html";
        charset iso-8859-1;
        echo hiya;
    }
    location /t {
        response_header_control set 'Content-Type' 'text/html; charset=UTF-8';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /t
--- response_body
hiya
--- response_headers
Content-Type: text/html; charset=UTF-8



=== TEST 8: override Cache-Control sent by upstream
--- config
    location /backend {
        content_by_lua_block {
            ngx.header['Cache-Control'] = 'max-age=0, no-cache'
            ngx.send_headers()
            ngx.say("done")
        }
    }
    location /t {
        response_header_control set 'Cache-Control' 'max-age=1800';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /t
--- response_headers
Cache-Control: max-age=1800
--- response_body
done



=== TEST 9: set multi-value header to single value
--- config
    location /backend {
        echo foo;
        add_header Foo a;
        add_header Foo c;
    }
    location /t {
        proxy_pass http://127.0.0.1:$server_port/backend;
        response_header_control set 'Foo' 'b';
    }
--- request
    GET /t
--- response_headers
Foo: b
--- response_body
foo



=== TEST 10: github #20 segfault fix (set)
--- config
    location = /t {
        response_header_control set 'Foo' '1';
        proxy_pass http://127.0.0.1:$server_port;
    }
--- request
GET /t
--- more_headers
Foo: bar
--- response_body_like: 301 Moved Permanently
--- error_code: 301
--- no_error_log
[error]



=== TEST 11: github #20 segfault fix (clear)
--- config
    location = /t {
        response_header_control clear 'Foo';
        proxy_pass http://127.0.0.1:$server_port;
    }
--- request
GET /t
--- more_headers
Foo: bar
--- response_body_like: 301 Moved Permanently
--- error_code: 301
--- no_error_log
[error]



=== TEST 12: cannot append builtin header
--- config
    location /foo {
        response_header_control append 'Server' 'extra';
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
can not append builtin headers
--- suppress_stderr
