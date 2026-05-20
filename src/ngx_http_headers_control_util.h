/*
 * Copyright (c) Yichun Zhang (agentzh)
 */


#ifndef NGX_HTTP_HEADERS_CONTROL_UTIL_H
#define NGX_HTTP_HEADERS_CONTROL_UTIL_H


#include "ngx_http_headers_control_filter_module.h"


#define ngx_http_headers_control_hash_literal(s)                                \
    ngx_http_headers_control_hash_str((u_char *) s, sizeof(s) - 1)


static ngx_inline ngx_uint_t
ngx_http_headers_control_hash_str(u_char *src, size_t n)
{
    ngx_uint_t  key;

    key = 0;

    while (n--) {
        key = ngx_hash(key, *src);
        src++;
    }

    return key;
}


extern ngx_uint_t  ngx_http_headers_control_location_hash;


ngx_int_t ngx_http_headers_control_parse_header(ngx_conf_t *cf,
    ngx_str_t *cmd_name, ngx_str_t *key, ngx_str_t *value,
    ngx_http_headers_control_header_val_t *hv,
    ngx_http_headers_control_opcode_t opcode,
    ngx_http_headers_control_set_header_t *handlers);

ngx_int_t ngx_http_headers_control_rm_header_helper(ngx_list_t *l,
    ngx_list_part_t *cur, ngx_uint_t i);


#endif /* NGX_HTTP_HEADERS_CONTROL_UTIL_H */
