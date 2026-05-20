/*
 * Copyright (C) Yichun Zhang (agentzh)
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#include "ngx_http_headers_control_util.h"


ngx_int_t
ngx_http_headers_control_parse_header(ngx_conf_t *cf, ngx_str_t *cmd_name,
    ngx_str_t *key, ngx_str_t *value,
    ngx_http_headers_control_header_val_t *hv,
    ngx_http_headers_control_opcode_t opcode,
    ngx_http_headers_control_set_header_t *handlers)
{
    ngx_uint_t                           i;
    ngx_http_compile_complex_value_t     ccv;
    u_char                              *p;

    if (key->len == 0) {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: empty header name", cmd_name);

        return NGX_ERROR;
    }

    hv->wildcard = (key->data[key->len - 1] == '*');
    if (hv->wildcard && key->len < 2) {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: wildcard key too short: %V",
                      cmd_name, key);
        return NGX_ERROR;
    }

    hv->hash = ngx_hash_key_lc(key->data, key->len);
    hv->key = *key;

    hv->offset = 0;

    for (i = 0; handlers[i].name.len; i++) {
        if (hv->key.len != handlers[i].name.len
            || ngx_strncasecmp(hv->key.data, handlers[i].name.data,
                               handlers[i].name.len) != 0)
        {
            dd("hv key comparison: %s <> %s", handlers[i].name.data,
               hv->key.data);

            continue;
        }

        hv->offset = handlers[i].offset;
        hv->handler = handlers[i].handler;

        break;
    }

    if (handlers[i].name.len == 0 && handlers[i].handler) {
        hv->offset = handlers[i].offset;
        hv->handler = handlers[i].handler;
    }

    if (opcode == ngx_http_headers_control_opcode_clear) {
        value->len = 0;
    }

    if (value->len == 0) {
        ngx_memzero(&hv->value, sizeof(ngx_http_complex_value_t));
        return NGX_OK;

    }

    /* Nginx request header value requires to be a null-terminated
     * C string */

    p = ngx_palloc(cf->pool, value->len + 1);
    if (p == NULL) {
        return NGX_ERROR;
    }

    ngx_memcpy(p, value->data, value->len);
    p[value->len] = '\0';
    value->data = p;
    value->len++; /* we should also compile the trailing '\0' */

    /* compile the header value as a complex value */

    ngx_memzero(&ccv, sizeof(ngx_http_compile_complex_value_t));

    ccv.cf = cf;
    ccv.value = value;
    ccv.complex_value = &hv->value;

    if (ngx_http_compile_complex_value(&ccv) != NGX_OK) {
        return NGX_ERROR;
    }

    return NGX_OK;
}


char *
ngx_http_headers_control_parse_directive(ngx_conf_t *cf, ngx_command_t *ngx_cmd,
    void *conf,
    ngx_http_headers_control_set_header_t *handlers,
    ngx_flag_t is_input)
{
    ngx_http_headers_control_loc_conf_t    *hlcf = conf;

    ngx_uint_t                              i;
    ngx_http_headers_control_header_val_t   *hv;
    ngx_str_t                              *arg;
    ngx_str_t                              *cmd_name;
    ngx_http_headers_control_opcode_t       opcode;
    ngx_str_t                               name = ngx_null_string;
    ngx_str_t                               value = ngx_null_string;
    ngx_flag_t                              is_builtin_header;
    ngx_int_t                               rc;

    ngx_http_headers_control_main_conf_t   *hmcf;

    arg = cf->args->elts;
    cmd_name = &arg[0];

    if (cf->args->nelts < 3) {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: operation is required "
                      "(set, clear, add, append, or rewrite)",
                      cmd_name);
        return NGX_CONF_ERROR;
    }

    if (arg[1].len == 3 && ngx_strncasecmp(arg[1].data, (u_char *) "set", 3) == 0) {
        opcode = ngx_http_headers_control_opcode_set;
    } else if (arg[1].len == 3 && ngx_strncasecmp(arg[1].data, (u_char *) "add", 3) == 0) {
        opcode = ngx_http_headers_control_opcode_add;
    } else if (arg[1].len == 5 && ngx_strncasecmp(arg[1].data, (u_char *) "clear", 5) == 0) {
        opcode = ngx_http_headers_control_opcode_clear;
    } else if (arg[1].len == 6 && ngx_strncasecmp(arg[1].data, (u_char *) "append", 6) == 0) {
        opcode = ngx_http_headers_control_opcode_append;
    } else if (arg[1].len == 7 && ngx_strncasecmp(arg[1].data, (u_char *) "rewrite", 7) == 0) {
        opcode = ngx_http_headers_control_opcode_rewrite;
    } else {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: unknown operation \"%V\" "
                      "(expected: set, clear, add, append, or rewrite)",
                      cmd_name, &arg[1]);
        return NGX_CONF_ERROR;
    }

    if (hlcf->headers == NULL) {
        hlcf->headers = ngx_array_create(cf->pool, 1,
                                    sizeof(ngx_http_headers_control_header_val_t));

        if (hlcf->headers == NULL) {
            return NGX_CONF_ERROR;
        }
    }

    hv = ngx_array_push(hlcf->headers);
    if (hv == NULL) {
        return NGX_CONF_ERROR;
    }

    ngx_memzero(hv, sizeof(ngx_http_headers_control_header_val_t));

    hv->opcode = opcode;

    /* args[0] = directive name, args[1] = operation, start from args[2] */

    for (i = 2; i < cf->args->nelts; i++) {

        if (arg[i].len == 0) {
            continue;
        }

        /* first non-empty arg is header name, second is header value */

        if (name.len == 0) {
            name = arg[i];
            continue;
        }

        if (value.len == 0) {
            value = arg[i];
            continue;
        }

        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: too many arguments (expected: header-name"
                      " header-value)", cmd_name);

        return NGX_CONF_ERROR;
    }

    if (name.len == 0) {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                      "%V: header name is required", cmd_name);

        return NGX_CONF_ERROR;
    }

    rc = ngx_http_headers_control_parse_header(cf, cmd_name,
                                            &name, &value,
                                            hv,
                                            opcode,
                                            handlers);

    if (rc != NGX_OK) {
        return NGX_CONF_ERROR;
    }

    if (opcode == ngx_http_headers_control_opcode_append) {
        is_builtin_header = 0;

        for (i = 0; handlers[i].name.len; i++) {
            if (hv->key.len == handlers[i].name.len
                && ngx_strncasecmp(hv->key.data, handlers[i].name.data,
                                   hv->key.len) == 0)
            {
                is_builtin_header = 1;
                break;
            }
        }

        if (is_builtin_header) {
            ngx_log_error(NGX_LOG_ERR, cf->log, 0,
                          "%V: can not append builtin headers \"%V\"",
                          cmd_name, &hv->key);

            return NGX_CONF_ERROR;
        }
    }

    hv->is_input = is_input;

    hmcf = ngx_http_conf_get_module_main_conf(cf,
                                         ngx_http_headers_control_filter_module);

    if (is_input) {
        hmcf->requires_handler = 1;
    } else {
        hmcf->requires_filter = 1;
    }

    return NGX_CONF_OK;
}


ngx_int_t
ngx_http_headers_control_rm_header_helper(ngx_list_t *l, ngx_list_part_t *cur,
    ngx_uint_t i)
{
    ngx_table_elt_t             *data;
    ngx_list_part_t             *new, *part;

    dd("list rm item: part %p, i %d, nalloc %d", cur, (int) i,
       (int) l->nalloc);

    data = cur->elts;

    dd("cur: nelts %d, nalloc %d", (int) cur->nelts,
       (int) l->nalloc);

    if (i == 0) {
        cur->elts = (char *) cur->elts + l->size;
        cur->nelts--;

        if (cur == l->last) {
            if (cur->nelts == 0) {
#if 1
                part = &l->part;

                if (part == cur) {
                    cur->elts = (char *) cur->elts - l->size;
                    /* do nothing */

                } else {
                    while (part->next != cur) {
                        if (part->next == NULL) {
                            return NGX_ERROR;
                        }

                        part = part->next;
                    }

                    l->last = part;
                    part->next = NULL;
                    dd("part nelts: %d", (int) part->nelts);
                    l->nalloc = part->nelts;
                }
#endif

            } else {
                l->nalloc--;
            }

            return NGX_OK;
        }

        if (cur->nelts == 0) {
            part = &l->part;

            if (part == cur) {
                ngx_http_headers_control_assert(cur->next != NULL);

                dd("remove 'cur' from the list by rewriting 'cur': "
                   "l->last: %p, cur: %p, cur->next: %p, part: %p",
                   l->last, cur, cur->next, part);

                if (l->last == cur->next) {
                    dd("last is cur->next");
                    l->part = *(cur->next);
                    l->last = part;
                    l->nalloc = part->nelts;

                } else {
                    l->part = *(cur->next);
                }

            } else {
                dd("remove 'cur' from the list");
                while (part->next != cur) {
                    if (part->next == NULL) {
                        return NGX_ERROR;
                    }

                    part = part->next;
                }

                part->next = cur->next;
            }

            return NGX_OK;
        }

        return NGX_OK;
    }

    if (i == cur->nelts - 1) {
        cur->nelts--;

        if (cur == l->last) {
            l->nalloc = cur->nelts;
        }

        return NGX_OK;
    }

    new = ngx_palloc(l->pool, sizeof(ngx_list_part_t));
    if (new == NULL) {
        return NGX_ERROR;
    }

    new->elts = &data[i + 1];
    new->nelts = cur->nelts - i - 1;
    new->next = cur->next;

    cur->nelts = i;
    cur->next = new;
    if (cur == l->last) {
        l->last = new;
        l->nalloc = new->nelts;
    }

    return NGX_OK;
}
