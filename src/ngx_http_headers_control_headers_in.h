
/*
 * Copyright (c) Yichun Zhang (agentzh)
 */


#ifndef NGX_HTTP_HEADERS_CONTROL_INPUT_HEADERS_H
#define NGX_HTTP_HEADERS_CONTROL_INPUT_HEADERS_H


#include "ngx_http_headers_control_filter_module.h"


/* output header setters and clearers */

ngx_int_t ngx_http_headers_control_exec_input_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv);

char *ngx_http_headers_control_set_input_headers(ngx_conf_t *cf,
    ngx_command_t *cmd, void *conf);

char *ngx_http_headers_control_clear_input_headers(ngx_conf_t *cf,
    ngx_command_t *cmd, void *conf);


#endif /* NGX_HTTP_HEADERS_CONTROL_INPUT_HEADERS_H */
