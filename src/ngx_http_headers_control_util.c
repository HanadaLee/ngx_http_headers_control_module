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
