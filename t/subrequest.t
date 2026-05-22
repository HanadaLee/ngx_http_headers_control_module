# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => blocks() * 2;

no_diff;

run_tests();

__DATA__

=== TEST 1: input header in subrequest propagated to main
--- config
    location /main {
        echo_location /foo;
        echo "main: $http_user_agent";
    }
    location /foo {
        set $val 'dog';
        request_header_control set 'User-Agent' '$val';
        proxy_pass http://127.0.0.1:$server_port/proxy;
    }
    location /proxy {
        echo "sub: $http_user_agent";
    }
--- request
    GET /main
--- more_headers
User-Agent: my-sock
--- response_body
sub: dog
main: dog
--- skip_nginx: 3: < 0.7.46



=== TEST 2: input header without setting from client
--- config
    location /main {
        echo_location /foo;
        echo "main: $http_user_agent";
    }
    location /foo {
        set $val 'dog';
        request_header_control set 'User-Agent' '$val';
        proxy_pass http://127.0.0.1:$server_port/proxy;
    }
    location /proxy {
        echo "sub: $http_user_agent";
    }
--- request
    GET /main
--- response_body
sub: dog
main: dog
--- skip_nginx: 3: < 0.7.46
