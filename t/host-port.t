use Test::Nginx::Socket 'no_plan';

repeat_each(2);
run_tests();

__DATA__

=== TEST 1: hostname with port
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:1984';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: example.com
X-HTTP-Host: example.com:1984
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 2: uppercase hostname and trailing dot
--- config
    location = /t {
        root html;
        request_header_control set Host 'EXAMPLE.COM.:65535';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: example.com
X-HTTP-Host: EXAMPLE.COM.:65535
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 3: IPv4 with port
--- config
    location = /t {
        root html;
        request_header_control set Host '127.0.0.1:80';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: 127.0.0.1
X-HTTP-Host: 127.0.0.1:80
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 4: IPv6 with port
--- config
    location = /t {
        root html;
        request_header_control set Host '[2001:DB8::1]:8443';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: [2001:db8::1]
X-HTTP-Host: [2001:DB8::1]:8443
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 5: IPv6 without port
--- config
    location = /t {
        root html;
        request_header_control set Host '[::1]';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: [::1]
X-HTTP-Host: [::1]
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 6: zero port follows nginx validation
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:0';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: example.com
X-HTTP-Host: example.com:0
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 7: empty port follows nginx validation
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: example.com
X-HTTP-Host: example.com:
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 8: leading zeroes in port
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:00080';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- response_headers
X-Host: example.com
X-HTTP-Host: example.com:00080
--- response_body
ok
--- no_error_log
[alert]
[crit]

=== TEST 9: port above 65535
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:65536';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 10: oversized port
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:999999999999999999999999';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 11: non-numeric port
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:http';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 12: negative port
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com:-1';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 13: extra colon
--- config
    location = /t {
        root html;
        request_header_control set Host 'example.com::80';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 14: IPv6 with invalid port
--- config
    location = /t {
        root html;
        request_header_control set Host '[::1]:65536';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 15: trailing characters after IPv6 literal
--- config
    location = /t {
        root html;
        request_header_control set Host '[::1]suffix';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- error_code_like: ^$
--- response_body eval
""
--- no_error_log
[alert]
[crit]

=== TEST 16: variable Host with IPv6 port
--- config
    location = /t {
        root html;
        request_header_control set Host '$http_x_target_host';
        add_header X-Host $host;
        add_header X-HTTP-Host $http_host;
    }
--- user_files
>>> t
ok
--- request
GET /t
--- more_headers
X-Target-Host: [2001:DB8::2]:443
--- response_headers
X-Host: [2001:db8::2]
X-HTTP-Host: [2001:DB8::2]:443
--- response_body
ok
--- no_error_log
[alert]
[crit]
