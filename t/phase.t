# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => 3;

no_diff;

run_tests();

__DATA__

=== TEST 1: set header in denied location
--- config
    location /foo {
        deny all;
        response_header_control set 'X-Foo' 'Blah';
    }
--- request
    GET /foo
--- response_headers
X-Foo: Blah
--- response_body_like: 403 Forbidden
--- error_code: 403
