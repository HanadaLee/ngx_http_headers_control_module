Name
====

**ngx_http_headers_control** — Modify request and response headers in Nginx.

*This module is not distributed with the Nginx source.* See [Installation](#installation).

Table of Contents
=================

- [Name](#name)
- [Table of Contents](#table-of-contents)
- [Synopsis](#synopsis)
- [Description](#description)
- [Directives](#directives)
  - [response\_header\_control](#response_header_control)
  - [request\_header\_control](#request_header_control)
  - [Operators](#operators)
  - [Inheritance \& Chaining](#inheritance--chaining)
    - [Execution order](#execution-order)
    - [Chaining](#chaining)
- [Limitations](#limitations)
- [Installation](#installation)
- [Test Suite](#test-suite)
- [Authors](#authors)
- [Copyright \& License](#copyright--license)
- [See Also](#see-also)

Synopsis
========

```nginx
 # set a response header
 response_header_control set Server my-server;

 # set, append, and clear response headers
 location /bar {
     response_header_control set X-MyHeader blah;
     response_header_control append X-MyHeader extra;
     response_header_control clear Content-Type;
 }

 # conditional: only if $debug is truthy
 if ($http_debug = 1) {
     set $debug 1;
 }
 response_header_control set X-Debug 1 if=$debug;

 # -n allows the next rule on the same header to continue
 response_header_control set -n X-Foo first;
 response_header_control set X-Foo second;  # this overrides

 # set a request header
 location /foo {
     set $my_host mydog;
     request_header_control set Host $my_host;
 }

 # rewrite a request header only if it already exists
 request_header_control rewrite X-Foo howdy;

 # wildcard clear removes all matching response headers
 response_header_control clear X-Hidden-*;

 # pass: define a header target for inheritance without runtime effect
 response_header_control pass X-Foo;
```

Description
===========

This module provides fine-grained control over request and response headers. It is an enhanced version of the standard [headers](http://nginx.org/en/docs/http/ngx_http_headers_module.html) module, adding support for clearing "builtin headers" like `Content-Type`, `Content-Length`, and `Server`.

There are two directives:

- `response_header_control` — modifies response headers (`r->headers_out`) in the output header filter phase.
- `request_header_control` — modifies request headers (`r->headers_in`) at the end of the rewrite phase after the standard [rewrite module](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html).

Both accept the same set of operators (see [Operators](#operators)). Variables are supported in header values but not in header names.

Rules may optionally specify:

- `-n` — continue the chain: subsequent rules for the same header are allowed to execute.
- `if=$var` — execute only if `$var` is truthy (non-empty, not `"0"`).
- `if!=$var` — execute only if `$var` is falsy.

If a condition is not met, the rule is skipped and does **not** break the chain.

Wildcard clear rules (`clear 'X-*'`) always execute — they neither check nor break the chain.

During config merge, child block rules execute first, parent rules are appended after. A child block's exact rule (without `-n` or `if=`) disables parent rules with the same header name. See [Inheritance & Chaining](#inheritance--chaining) for details.

[Back to TOC](#table-of-contents)

Directives
==========

response_header_control
-----------------------

**syntax:** *response_header_control `<operator>` [-n] `<header-name>` [header-value] [if=cond | if!=cond]*

**default:** *no*

**context:** *http, server, location, location if*

**phase:** *output-header-filter*

```nginx
 response_header_control set Server my-server;
 response_header_control clear X-Hidden-*;
 response_header_control add X-Default 1;
 response_header_control append Set-Cookie name=lynch;
 response_header_control rewrite X-Foo new-value;
 response_header_control pass X-Header;
```

Not allowed in *server* if blocks.

request_header_control
----------------------

**syntax:** *request_header_control `<operator>` [-n] `<header-name>` [header-value] [if=cond | if!=cond]*

**default:** *no*

**context:** *http, server, location, location if*

**phase:** *rewrite tail*

```nginx
 request_header_control set Host foo;
 request_header_control clear User-Agent;
 request_header_control rewrite X-Foo new-value;
 request_header_control add X-Default 1;
```

[Back to TOC](#table-of-contents)

Operators
---------

| Operator | Header name | Header value | Description |
|---|---|---|---|
| `set` | required | required | Replace the header value, or add it if absent |
| `clear` | required | — | Remove the header. Wildcard suffix `*` matches by prefix |
| `add` | required | required | Set only if the header does **not** already exist |
| `append` | required | required | Add a new entry without removing existing ones. Cannot be used on builtin headers |
| `rewrite` | required | required | Replace the value only if the header **already** exists |
| `pass` | required | — | Define the header target for inheritance. No runtime effect |

[Back to TOC](#table-of-contents)

Inheritance & Chaining
----------------------

### Execution order

Child block rules execute first, parent rules are appended after.

### Chaining

Exact rules (non-wildcard) without `-n` **break the chain** for their target header after execution, preventing subsequent rules from modifying it:

```nginx
 response_header_control set X-Foo a;       # breaks chain
 response_header_control set X-Foo b;       # skipped
```

With `-n`, the chain continues:

```nginx
 response_header_control set -n X-Foo a;    # chain continues
 response_header_control set X-Foo b;       # executes
```

Wildcard rules (`clear X-*`) always execute — they do not check chain state and do not break it:

```nginx
 response_header_control clear X-*;           # always executes
 response_header_control set X-Foo after;   # also executes
```

[Back to TOC](#table-of-contents)

Limitations
===========

- Unlike the standard [headers](http://nginx.org/en/docs/http/ngx_http_headers_module.html) module, this module does not automatically coordinate `Expires`, `Cache-Control`, and `Last-Modified`. Use them together if needed.
- The `Connection` response header cannot be removed via this module because `ngx_http_header_filter_module` in the Nginx core runs *after* this module's filter.
- Variables are not supported in header names.

[Back to TOC](#table-of-contents)

Installation
============

```bash
 wget 'http://nginx.org/download/nginx-1.17.8.tar.gz'
 tar -xzvf nginx-1.17.8.tar.gz
 cd nginx-1.17.8/

 ./configure --prefix=/opt/nginx \
     --add-module=/path/to/ngx_http_headers_control_module

 make
 make install
```

Starting from Nginx 1.9.11, use `--add-dynamic-module=PATH` for a dynamic module and load it with:

```nginx
load_module /path/to/modules/ngx_http_headers_control_module.so;
```

This module is included and enabled by default in the [OpenResty bundle](http://openresty.org).

[Back to TOC](#table-of-contents)

Test Suite
==========

A Perl-driven test suite using [Test::Nginx](http://search.cpan.org/perldoc?Test::Nginx) is included. Requires [proxy](http://nginx.org/en/docs/http/ngx_http_proxy_module.html), [rewrite](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html), and [echo](https://github.com/openresty/echo-nginx-module) modules.

```bash
 $ PATH=/path/to/nginx-with-headers-control-module:$PATH prove -r t
 $ TEST_NGINX_USE_VALGRIND=1 prove -r t   # with valgrind
```

[Back to TOC](#table-of-contents)

Authors
=======

- Yichun "agentzh" Zhang (章亦春) <agentzh@gmail.com>, OpenResty Inc.
- Bernd Dorn (<http://www.lovelysystems.com/>)
- Hanada (im@hanada.info)

[Back to TOC](#table-of-contents)

Copyright & License
===================

Based on the standard [headers](http://nginx.org/en/docs/http/ngx_http_headers_module.html) module in Nginx (copyright Igor Sysoev).

Copyright (c) 2009-2026, Yichun "agentzh" Zhang (章亦春), OpenResty Inc.

Copyright (c) 2010-2013, Bernd Dorn.

Copyright (c) Hanada.

See [LICENSE](LICENSE).

[Back to TOC](#table-of-contents)

See Also
========

- Original Nginx mailing list thread: ["A question about add_header replication"](http://forum.nginx.org/read.php?2,11206,11738)
- Original announcement: ["The 'headers_more' module"](http://forum.nginx.org/read.php?2,23460)
- Original [blog post](http://agentzh.blogspot.com/2009/11/headers-more-module-scripting-input-and.html)
- [echo-nginx-module](https://github.com/openresty/echo-nginx-module) for testing
- Standard [headers module](http://nginx.org/en/docs/http/ngx_http_headers_module.html)

[Back to TOC](#table-of-contents)