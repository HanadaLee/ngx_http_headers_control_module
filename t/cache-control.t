use Test::Nginx::Socket 'no_plan';

repeat_each(2);
run_tests();

__DATA__

=== TEST 1: clear missing Cache-Control
--- config
    location = /t {
        response_header_control clear Cache-Control;
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 2: set missing Cache-Control to an empty literal
--- config
    location = /t {
        response_header_control set Cache-Control '';
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 3: set missing Cache-Control to an empty variable
--- config
    location = /t {
        response_header_control set Cache-Control $arg_value;
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 4: clear missing Cache-Control twice
--- config
    location = /t {
        response_header_control clear -n Cache-Control;
        response_header_control clear Cache-Control;
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 5: clear missing Cache-Control then set a value
--- config
    location = /t {
        response_header_control clear -n Cache-Control;
        response_header_control set Cache-Control private;
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
Cache-Control: private
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 6: clear all upstream Cache-Control entries
--- config
    location = /backend {
        add_header Cache-Control public;
        add_header Cache-Control max-age=60;
        return 200 "ok\n";
    }
    location = /t {
        response_header_control clear Cache-Control;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 7: set upstream Cache-Control to an empty variable
--- config
    location = /backend {
        add_header Cache-Control public;
        add_header Cache-Control max-age=60;
        return 200 "ok\n";
    }
    location = /t {
        response_header_control set Cache-Control $arg_value;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 8: clear upstream Cache-Control then set a value
--- config
    location = /backend {
        add_header Cache-Control public;
        add_header Cache-Control max-age=60;
        return 200 "ok\n";
    }
    location = /t {
        response_header_control clear -n Cache-Control;
        response_header_control set Cache-Control private;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
GET /t
--- response_headers
Cache-Control: private
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 9: clear Cache-Control case-insensitively
--- config
    location = /backend {
        add_header Cache-Control public;
        add_header Cache-Control max-age=60;
        return 200 "ok\n";
    }
    location = /t {
        response_header_control clear cache-control;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
GET /t
--- response_headers
! Cache-Control
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 10: set a nonempty value without an existing header
--- config
    location = /t {
        response_header_control set Cache-Control private;
        return 200 "ok\n";
    }
--- request
GET /t
--- response_headers
Cache-Control: private
--- response_body
ok
--- no_error_log
[error]
[alert]

=== TEST 11: replace multiple upstream Cache-Control entries
--- config
    location = /backend {
        add_header Cache-Control public;
        add_header Cache-Control max-age=60;
        return 200 "ok\n";
    }
    location = /t {
        response_header_control set Cache-Control private;
        proxy_pass http://127.0.0.1:$server_port/backend;
    }
--- request
GET /t
--- response_headers
Cache-Control: private
--- response_body
ok
--- no_error_log
[error]
[alert]
