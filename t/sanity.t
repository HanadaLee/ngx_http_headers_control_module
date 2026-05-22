# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * 52;

log_level("warn");
no_diff;

run_tests();

__DATA__

=== TEST 1: set a header
--- config
    location /foo {
        echo ok;
        response_header_control set 'X-Foo' 'Blah';
    }
--- request
    GET /foo
--- response_headers
X-Foo: Blah
--- response_body
ok



=== TEST 2: clear a header that exists
--- config
    location = /backend {
        add_header X-Hidden "value";
        echo hi;
    }
    location /foo {
        response_header_control clear 'X-Hidden';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
! X-Hidden
--- response_body
hi



=== TEST 3: clear with wildcard
--- config
    location = /backend {
        add_header X-One "1";
        add_header X-Two "2";
        echo hi;
    }
    location /foo {
        response_header_control clear 'X-*';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
! X-One
! X-Two
--- response_body
hi



=== TEST 4: add - header absent (should add)
--- config
    location /foo {
        echo ok;
        response_header_control add 'X-New' 'added';
    }
--- request
    GET /foo
--- response_headers
X-New: added
--- response_body
ok



=== TEST 5: add - header exists (should not change)
--- config
    location /foo {
        response_header_control set 'X-Foo' 'original';
        response_header_control add 'X-Foo' 'should-not-appear';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: original
--- response_body
ok



=== TEST 6: append alongside existing
--- config
    location /foo {
        response_header_control set 'X-Upstream' 'v1';
        response_header_control append 'X-Upstream' 'v2';
        echo ok;
    }
--- request
    GET /foo
--- raw_response_headers_like eval
qr/X-Upstream: v1\r\nX-Upstream: v2/
--- response_body
ok



=== TEST 7: rewrite - header exists (should update)
--- config
    location /foo {
        response_header_control set 'X-Foo' 'old';
        response_header_control rewrite 'X-Foo' 'new';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: new
--- response_body
ok



=== TEST 8: rewrite - header absent (should not add)
--- config
    location /foo {
        echo ok;
        response_header_control rewrite 'X-Foo' 'val';
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
ok



=== TEST 9: -n unlocks for subsequent rules
--- config
    location /foo {
        response_header_control set -n 'X-Foo' 'first';
        response_header_control set 'X-Foo' 'second';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: second
--- response_body
ok



=== TEST 10: without -n, first rule locks
--- config
    location /foo {
        response_header_control set 'X-Foo' 'first';
        response_header_control set 'X-Foo' 'second';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: first
--- response_body
ok



=== TEST 11: wildcard does not lock, subsequent set executes
--- config
    location = /backend {
        add_header X-Test "orig";
        echo hi;
    }
    location /foo {
        response_header_control clear 'X-*';
        response_header_control set 'X-Test' 'newval';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
X-Test: newval
--- response_body
hi



=== TEST 12: if= condition truthy
--- config
    location /foo {
        set $debug "1";
        response_header_control set 'X-Debug' 'on' if=$debug;
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Debug: on
--- response_body
ok



=== TEST 13: if= condition falsy (empty)
--- config
    location /foo {
        response_header_control set 'X-Foo' 'val' if=$http_xxx;
        echo ok;
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
ok



=== TEST 14: if!= condition (negated, truthy value skips)
--- config
    location /foo {
        set $mode "1";
        response_header_control set 'X-Foo' 'val' if!=$mode;
        echo ok;
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
ok



=== TEST 15: if!= condition (negated, falsy value executes)
--- config
    location /foo {
        response_header_control set 'X-Foo' 'val' if!=$http_xxx;
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: val
--- response_body
ok



=== TEST 16: conditional rule does not lock when condition fails
--- config
    location /foo {
        response_header_control set 'X-Foo' 'cond' if=$http_xxx;
        response_header_control set 'X-Foo' 'fallback';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: fallback
--- response_body
ok



=== TEST 17: conditional rule locks when condition succeeds
--- config
    location /foo {
        set $flag "1";
        response_header_control set 'X-Foo' 'cond' if=$flag;
        response_header_control set 'X-Foo' 'fallback';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Foo: cond
--- response_body
ok



=== TEST 18: child overrides parent (inheritance)
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        response_header_control set 'X-Foo' 'child';
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: child
--- response_body
ok



=== TEST 19: child defines different header, parent kept
--- config
    response_header_control set 'X-Foo' 'parent';
    response_header_control set 'X-Bar' 'parent-bar';
    location /child {
        response_header_control set 'X-Foo' 'child';
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: child
X-Bar: parent-bar
--- response_body
ok



=== TEST 20: child with -n does not disable parent
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        response_header_control set -n 'X-Foo' 'child';
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: parent
--- response_body
ok



=== TEST 21: child with if= does not disable parent, condition fails
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        response_header_control set 'X-Foo' 'child' if=$http_xxx;
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: parent
--- response_body
ok



=== TEST 22: child with if= does not disable parent, condition succeeds
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        set $flag "1";
        response_header_control set 'X-Foo' 'child' if=$flag;
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: child
--- response_body
ok



=== TEST 23: pass defines header for inheritance
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        response_header_control pass 'X-Foo';
        echo ok;
    }
--- request
    GET /child
--- response_headers
! X-Foo
--- response_body
ok



=== TEST 24: pass with if= condition fails, parent fallback
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        response_header_control pass 'X-Foo' if=$http_xxx;
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Foo: parent
--- response_body
ok



=== TEST 25: pass with if= condition succeeds, parent disabled
--- config
    response_header_control set 'X-Foo' 'parent';
    location /child {
        set $flag "1";
        response_header_control pass 'X-Foo' if=$flag;
        echo ok;
    }
--- request
    GET /child
--- response_headers
! X-Foo
--- response_body
ok



=== TEST 26: clear with -n allows subsequent set
--- config
    location = /backend {
        add_header X-Foo "orig";
        echo hi;
    }
    location /foo {
        response_header_control clear -n 'X-Foo';
        response_header_control set 'X-Foo' 'replaced';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
X-Foo: replaced
--- response_body
hi



=== TEST 27: clear without -n locks, subsequent set skipped
--- config
    location = /backend {
        add_header X-Foo "orig";
        echo hi;
    }
    location /foo {
        response_header_control clear 'X-Foo';
        response_header_control set 'X-Foo' 'after';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
hi



=== TEST 56: empty header name error
--- config
    location /foo {
        response_header_control set '' 'val';
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
empty header name
--- suppress_stderr



=== TEST 29: header name with space error
--- config
    location /foo {
        response_header_control set 'X Bad' 'val';
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
whitespace
--- suppress_stderr



=== TEST 30: too few arguments
--- config
    location /foo {
        response_header_control set;
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
too few arguments
--- suppress_stderr



=== TEST 31: unknown operation
--- config
    location /foo {
        response_header_control foo 'X-Test' 'val';
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
unknown operation
--- suppress_stderr



=== TEST 32: set header with variables
--- config
    location /foo {
        set $my_val "dynamic";
        response_header_control set 'X-Dyn' '$my_val';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Dyn: dynamic
--- response_body
ok



=== TEST 33: add with -n allows wildcard to delete
--- config
    location = /backend {
        add_header X-Test "orig";
        echo hi;
    }
    location /foo {
        response_header_control add -n 'X-Test' 'added';
        response_header_control clear 'X-*';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
! X-Test
--- response_body
hi



=== TEST 34: add without -n locks, wildcard still executes
--- config
    location = /backend {
        add_header X-Test "orig";
        echo hi;
    }
    location /foo {
        response_header_control add 'X-Test' 'added';
        response_header_control clear 'X-*';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
X-Test: added
--- response_body
hi



=== TEST 35: append with duplicate values
--- config
    location /foo {
        response_header_control append 'X-Dup' 'one';
        response_header_control append 'X-Dup' 'two';
        echo ok;
    }
--- request
    GET /foo
--- raw_response_headers_like eval
qr/X-Dup: one\r\nX-Dup: two/
--- response_body
ok



=== TEST 36: clear duplicate builtin headers
--- config
    location = /backend {
        add_header pragma no-cache;
        add_header pragma no-cache;
        echo hi;
    }
    location /foo {
        response_header_control clear 'pragma';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
!pragma
--- response_body
hi



=== TEST 37: HTTP 0.9 does not set header
--- config
    location /foo {
        response_header_control set 'X-Foo' 'howdy';
        echo ok;
    }
--- raw_request eval
"GET /foo\r\n"
--- response_headers
! X-Foo
--- response_body
ok
--- http09



=== TEST 38: request_header_control basic set
--- config
    location /foo {
        set $new_host "myhost";
        request_header_control set 'Host' '$new_host';
        echo $http_host;
    }
--- request
    GET /foo
--- response_body
myhost



=== TEST 39: request_header_control clear
--- config
    location /foo {
        request_header_control clear 'User-Agent';
        echo "ua=[$http_user_agent]";
    }
--- request
    GET /foo
--- response_body
ua=[]



=== TEST 40: request_header_control rewrite (exists)
--- config
    location /foo {
        request_header_control rewrite 'User-Agent' 'CustomUA';
        echo $http_user_agent;
    }
--- request
    GET /foo
--- response_body
CustomUA



=== TEST 41: request_header_control add (absent, should add)
--- config
    location /foo {
        request_header_control add 'X-New' 'newval';
        echo "val=[$http_x_new]";
    }
--- request
    GET /foo
--- response_body
val=[newval]



=== TEST 42: request_header_control add (exists, should not change)
--- config
    location /foo {
        request_header_control set -n 'X-Foo' 'original';
        request_header_control add 'X-Foo' 'should-not-appear';
        echo "val=[$http_x_foo]";
    }
--- request
    GET /foo
--- response_body
val=[original]



=== TEST 43: multiple rules interaction
--- config
    location /foo {
        response_header_control set 'X-A' 'a1';
        response_header_control set 'X-B' 'b1';
        response_header_control set -n 'X-A' 'a2';
        response_header_control set 'X-A' 'a3';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-A: a3
X-B: b1
--- response_body
ok



=== TEST 44: builtin header set
--- config
    location /foo {
        response_header_control set 'Server' 'myServer';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Server: myServer
--- response_body
ok



=== TEST 45: cannot append builtin header
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



=== TEST 46: wildcard does not affect exact rule at same level
--- config
    location = /backend {
        add_header X-A "a";
        add_header X-B "b";
        echo hi;
    }
    location /foo {
        response_header_control clear 'X-*';
        response_header_control set 'X-A' 'kept';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
X-A: kept
! X-B
--- response_body
hi



=== TEST 47: Content-Type set
--- config
    location /foo {
        default_type 'text/plain';
        response_header_control set 'Content-Type' 'text/html';
        echo ok;
    }
--- request
    GET /foo
--- response_headers
Content-Type: text/html
--- response_body
ok



=== TEST 48: Content-Length set
--- config
    location /foo {
        response_header_control set 'Content-Length' '5';
        echo 12345;
    }
--- request
    GET /foo
--- response_headers
Content-Length: 5
--- response_body
12345



=== TEST 49: two-level inheritance with wildcard and exact
--- config
    response_header_control clear 'X-*';
    response_header_control set 'X-Main' 'main';
    location /sub {
        response_header_control set 'X-Sub' 'sub';
        echo ok;
    }
--- request
    GET /sub
--- response_headers
! X-Main
X-Sub: sub
--- response_body
ok



=== TEST 50: request_header_control set X-Forwarded-For
--- config
    location /foo {
        request_header_control set 'X-Forwarded-For' '1.2.3.4';
        echo "xff=[$http_x_forwarded_for]";
    }
--- request
    GET /foo
--- response_body
xff=[1.2.3.4]



=== TEST 51: locked by previous exact rule, wildcard still deletes
--- config
    location = /backend {
        add_header X-Bar "bar";
        echo hi;
    }
    location /foo {
        response_header_control set 'X-Foo' 'locked';
        response_header_control clear 'X-*';
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
! X-Bar
X-Foo: locked
--- response_body
hi



=== TEST 52: conditional wildcard obeying if=
--- config
    location = /backend {
        add_header X-A "a";
        add_header X-B "b";
        echo hi;
    }
    location /foo {
        set $do_clear "";
        response_header_control clear 'X-*' if=$do_clear;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
    GET /foo
--- response_headers
X-A: a
X-B: b
--- response_body
hi
