# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

if (!$ENV{TEST_NGINX_CONDITION}) {
    plan skip_all => 'requires an NGX_CONDITION-enabled build';
}

repeat_each(2);

plan tests => repeat_each() * 10;

log_level("warn");
no_diff;

run_tests();

__DATA__

=== TEST 1: response rule executes when condition matches
--- config
    location /foo {
        condition enabled str_eq $arg_enabled 1;
        when enabled {
            response_header_control set X-Condition matched;
        }
        echo ok;
    }
--- request
    GET /foo?enabled=1
--- response_headers
X-Condition: matched
--- response_body
ok



=== TEST 2: response rule falls through when condition misses
--- config
    location /foo {
        when enabled {
            response_header_control set X-Condition matched;
        }
        response_header_control set X-Condition fallback;
        condition enabled str_eq $arg_enabled 1;
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Condition: fallback
--- response_body
ok



=== TEST 3: negated condition reference
--- config
    location /foo {
        condition blocked str_eq $arg_blocked 1;
        when !blocked {
            response_header_control set X-Access allowed;
        }
        echo ok;
    }
--- request
    GET /foo
--- response_headers
X-Access: allowed
--- response_body
ok



=== TEST 4: multiple when references use implicit AND
--- config
    location /foo {
        condition is_get str_eq $request_method GET;
        condition is_public str_eq $arg_scope public;
        when is_get is_public {
            response_header_control set X-Combined yes;
        }
        echo ok;
    }
--- request
    GET /foo?scope=public
--- response_headers
X-Combined: yes
--- response_body
ok



=== TEST 5: request header rule uses condition result
--- config
    location /foo {
        condition enabled str_eq $arg_enabled 1;
        when enabled {
            request_header_control set X-Condition request;
        }
        echo $http_x_condition;
    }
--- request
    GET /foo?enabled=1
--- response_body
request



=== TEST 6: conditional child miss preserves parent fallback
--- config
    response_header_control set X-Scoped parent;

    location /child {
        when child_enabled {
            response_header_control set X-Scoped child;
        }
        condition child_enabled str_eq $arg_enabled 1;
        echo ok;
    }
--- request
    GET /child
--- response_headers
X-Scoped: parent
--- response_body
ok



=== TEST 7: matching conditional child locks parent fallback
--- config
    response_header_control set X-Scoped parent;

    location /child {
        when child_enabled {
            response_header_control set X-Scoped child;
        }
        condition child_enabled str_eq $arg_enabled 1;
        echo ok;
    }
--- request
    GET /child?enabled=1
--- response_headers
X-Scoped: child
--- response_body
ok



=== TEST 8: legacy if parameter is rejected with NGX_CONDITION
--- config
    location /foo {
        response_header_control set X-Legacy invalid if=$arg_enabled;
        echo ok;
    }
--- request
    GET /foo
--- must_die
--- error_log chomp
invalid parameter "if=$arg_enabled"
--- suppress_stderr



=== TEST 9: or condition accepts more than two references
--- config
    location /foo {
        condition first str_eq $arg_first 1;
        condition second str_eq $arg_second 1;
        condition third str_eq $arg_third 1;
        condition any_enabled or first second third;
        when any_enabled {
            response_header_control set X-Condition matched;
        }
        echo ok;
    }
--- request
    GET /foo?third=1
--- response_headers
X-Condition: matched
--- response_body
ok



=== TEST 10: logical operators accept negated references
--- config
    location /foo {
        condition b str_eq $arg_b 1;
        condition c str_eq $arg_c 1;
        condition d str_eq $arg_d 1;
        condition and_expr and b !c;
        condition or_expr or c !d;
        condition not_expr not !b;
        when and_expr or_expr not_expr {
            response_header_control set X-Condition matched;
        }
        echo ok;
    }
--- request
    GET /foo?b=1
--- response_headers
X-Condition: matched
--- response_body
ok
