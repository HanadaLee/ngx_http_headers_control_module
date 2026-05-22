# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * 32;

no_long_string();

run_tests();

__DATA__

=== TEST 1: client header passed through unchanged
--- config
    location /foo {
        echo $http_x_foo;
    }
--- request
    GET /foo
--- more_headers
X-Foo: blah
--- response_body
blah



=== TEST 2: set input header
--- config
    location /foo {
        request_header_control set 'X-Foo' 'howdy';
        echo $http_x_foo;
    }
--- request
    GET /foo
--- more_headers
X-Foo: blah
--- response_body
howdy



=== TEST 3: rewrite Content-Length
--- config
    location /bar {
        request_header_control set 'Content-Length' '2048';
        echo_read_request_body;
        echo_request_body;
    }
--- request eval
"POST /bar\n" .
"a" x 4096
--- response_body eval
"a" x 2048
--- timeout: 15



=== TEST 4: set Host and User-Agent
--- config
    location /bar {
        request_header_control set 'Host' 'foo';
        request_header_control set 'User-Agent' 'blah';
        echo "Host: $host";
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /bar
--- response_body
Host: foo
User-Agent: blah



=== TEST 5: clear Host and User-Agent
--- config
    location /bar {
        request_header_control clear 'Host';
        request_header_control clear 'User-Agent';
        echo "Host: $host";
        echo "User-Agent: $http_user_agent";
    }
--- request
GET /bar
--- response_body
Host: localhost
User-Agent:



=== TEST 6: clear Content-Length
--- config
    location /bar {
        request_header_control clear 'Content-Length';
        echo "Content-Length: $http_content_length";
    }
--- request
POST /bar
hello
--- response_body
Content-Length:



=== TEST 7: set Content-Type
--- config
    location /bar {
        request_header_control set 'Content-Type' 'text/css';
        echo "Content-Type: $content_type";
    }
--- request
POST /bar
hello
--- more_headers
Content-Type: text/plain
--- response_body
Content-Type: text/css



=== TEST 8: rewrite (replace only if exists)
--- config
    location /foo {
        request_header_control rewrite 'X-Foo' 'howdy';
        echo $http_x_foo;
    }
--- request
    GET /foo
--- more_headers
X-Foo: blah
--- response_body
howdy



=== TEST 9: rewrite with no existing header (should not add)
--- config
    location /foo {
        request_header_control rewrite 'X-Foo' 'howdy';
        echo "val=[$http_x_foo]";
    }
--- request
    GET /foo
--- response_body
val=[]



=== TEST 10: clear input header removes all instances
--- config
    location = /t {
        request_header_control clear 'Foo';
        proxy_pass http://127.0.0.1:$server_port/echo;
        proxy_http_version 1.0;
        proxy_set_header Connection close;
    }
    location = /echo {
        echo "Foo: [$http_foo]";
    }
--- request
GET /t
--- more_headers
Foo: foo
Foo: bah
--- response_body
Foo: []



=== TEST 11: Converting POST to GET by clearing Content headers
--- config
    location /t {
        request_header_control clear 'Content-Type';
        request_header_control clear 'Content-Length';
        proxy_pass http://127.0.0.1:$server_port/back;
        proxy_http_version 1.0;
        proxy_set_header Connection close;
    }
    location /back {
        echo $echo_client_request_headers;
    }
--- request
POST /t
hello world
--- more_headers
Content-Type: application/ocsp-request
Test-Header: 1
--- no_error_log
[error]



=== TEST 12: set X-Forwarded-For
--- config
    location = /t {
        request_header_control set 'X-Forwarded-For' '8.8.8.8';
        proxy_pass http://127.0.0.1:$server_port/back;
        proxy_http_version 1.0;
        proxy_set_header Connection close;
        proxy_set_header Foo $proxy_add_x_forwarded_for;
    }
    location = /back {
        echo "Foo: $http_foo";
    }
--- request
GET /t
--- response_body
Foo: 8.8.8.8, 127.0.0.1



=== TEST 13: clear X-Forwarded-For
--- config
    location = /t {
        request_header_control clear 'X-Forwarded-For';
        proxy_pass http://127.0.0.1:$server_port/back;
        proxy_http_version 1.0;
        proxy_set_header Connection close;
        proxy_set_header Foo $proxy_add_x_forwarded_for;
    }
    location = /back {
        echo "Foo: $http_foo";
    }
--- request
GET /t
--- more_headers
X-Forwarded-For: 8.8.8.8
--- response_body
Foo: 127.0.0.1



=== TEST 14: HTTP 0.9 does not process input headers
--- config
    location /foo {
        request_header_control set 'X-Foo' 'howdy';
        echo "x-foo: $http_x_foo";
    }
--- raw_request eval
"GET /foo\r\n"
--- response_body
x-foo:
--- http09



=== TEST 15: Host header with port
--- config
    location /bar {
        request_header_control set 'Host' 'agentzh.org:1984';
        echo "host var: $host";
        echo "http_host var: $http_host";
    }
--- request
GET /bar
--- response_body
host var: agentzh.org
http_host var: agentzh.org:1984



=== TEST 16: wildcard clear on input headers
--- config
    location /hello {
        request_header_control clear 'X-Hidden-*';
        content_by_lua '
            ngx.say("X-Hidden-One: ", ngx.var.http_x_hidden_one)
            ngx.say("X-Hidden-Two: ", ngx.var.http_x_hidden_two)
        ';
    }
--- request
    GET /hello
--- more_headers
X-Hidden-One: i am hidden
X-Hidden-Two: me 2
--- response_body
X-Hidden-One: nil
X-Hidden-Two: nil



=== TEST 17: set input header with Accept-Encoding for gzip
--- config
    location /bar {
        request_header_control set 'Accept-Encoding' 'gzip';
        gzip on;
        gzip_min_length 1;
        gzip_types text/plain;
        default_type 'text/plain';
    }
--- user_files
">>> bar
" . ("hello" x 512)
--- request
GET /bar
--- response_headers
Content-Encoding: gzip
