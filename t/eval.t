# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(3);

plan tests => repeat_each() * blocks();

no_long_string();

run_tests();

__DATA__

=== TEST 1: set input header in eval block
--- config
    location /foo {
        eval_subrequest_in_memory off;
        eval_override_content_type text/plain;
        eval $res {
            echo -n 1;
        }
        if ($res = '1') {
            request_header_control set 'Foo' 'Bar';
            echo "OK";
            break;
        }
        echo "NOT OK";
    }
--- request
    GET /foo
--- response_body
OK
