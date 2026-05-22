
/*
 * Copyright (C) Yichun Zhang (agentzh)
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#include "ngx_http_headers_control_headers_out.h"
#include "ngx_http_headers_control_util.h"


static ngx_int_t ngx_http_headers_control_set_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_set_header_helper(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value, ngx_table_elt_t **output_header, ngx_flag_t no_create);
static ngx_int_t ngx_http_headers_control_set_builtin_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_set_accept_ranges_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_set_content_length_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_set_content_type_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_clear_builtin_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_clear_content_length_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);
static ngx_int_t ngx_http_headers_control_set_builtin_multi_header(
    ngx_http_request_t *r, ngx_http_headers_control_header_val_t *hv,
    ngx_str_t *value);


static ngx_http_headers_control_set_header_t
    ngx_http_headers_control_set_handlers[]
    = {

    { ngx_string("Server"),
                 offsetof(ngx_http_headers_out_t, server),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Date"),
                 offsetof(ngx_http_headers_out_t, date),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Content-Encoding"),
                 offsetof(ngx_http_headers_out_t, content_encoding),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Location"),
                 offsetof(ngx_http_headers_out_t, location),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Refresh"),
                 offsetof(ngx_http_headers_out_t, refresh),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Last-Modified"),
                 offsetof(ngx_http_headers_out_t, last_modified),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Content-Range"),
                 offsetof(ngx_http_headers_out_t, content_range),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Accept-Ranges"),
                 offsetof(ngx_http_headers_out_t, accept_ranges),
                 ngx_http_headers_control_set_accept_ranges_header },

    { ngx_string("WWW-Authenticate"),
                 offsetof(ngx_http_headers_out_t, www_authenticate),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Expires"),
                 offsetof(ngx_http_headers_out_t, expires),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("E-Tag"),
                 offsetof(ngx_http_headers_out_t, etag),
                 ngx_http_headers_control_set_builtin_header },

    { ngx_string("Content-Length"),
                 offsetof(ngx_http_headers_out_t, content_length),
                 ngx_http_headers_control_set_content_length_header },

    { ngx_string("Content-Type"),
                 0,
                 ngx_http_headers_control_set_content_type_header },

    { ngx_string("Cache-Control"),
                 offsetof(ngx_http_headers_out_t, cache_control),
                 ngx_http_headers_control_set_builtin_multi_header },

    { ngx_null_string, 0, ngx_http_headers_control_set_header }
};


ngx_int_t
ngx_http_headers_control_exec_output_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv,
    ngx_http_headers_control_bitmap_t *locked)
{
    ngx_str_t  value, val;

    if (hv->filter) {
        if (ngx_http_complex_value(r, hv->filter, &val) != NGX_OK) {
            return NGX_ERROR;
        }

        if (val.len == 0 || (val.len == 1 && val.data[0] == '0')) {
            if (!hv->negative) {
                return NGX_DECLINED;
            }

        } else {
            if (hv->negative) {
                return NGX_DECLINED;
            }
        }
    }

    if (hv->opcode == ngx_http_headers_control_opcode_pass) {
        return NGX_OK;
    }

    if (ngx_http_complex_value(r, &hv->value, &value) != NGX_OK) {
        return NGX_ERROR;
    }

    if (value.len) {
        value.len--;  /* remove the trailing '\0' added by
                         ngx_http_headers_control_parse_header */
    }

    hv->_rt_locked = locked;

    return hv->handler(r, hv, &value);
}


static ngx_int_t
ngx_http_headers_control_set_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    return ngx_http_headers_control_set_header_helper(r, hv, value, NULL, 0);
}


static ngx_int_t
ngx_http_headers_control_set_header_helper(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value,
    ngx_table_elt_t **output_header, ngx_flag_t no_create)
{
    ngx_table_elt_t             *h;
    ngx_list_part_t             *part;
    ngx_uint_t                   i;
    ngx_flag_t                   matched = 0;

    dd_enter();

#if 1
    if (r->headers_out.location
        && r->headers_out.location->value.len
        && r->headers_out.location->value.data[0] == '/')
    {
        /* XXX ngx_http_core_find_config_phase, for example,
         * may not initialize the "key" and "hash" fields
         * for a nasty optimization purpose, and
         * we have to work-around it here */

        r->headers_out.location->hash = ngx_http_headers_control_location_hash;
        ngx_str_set(&r->headers_out.location->key, "Location");
    }
#endif

    if (hv->opcode == ngx_http_headers_control_opcode_append) {
        goto append;
    }

    part = &r->headers_out.headers.part;
    h = part->elts;

    for (i = 0; /* void */; i++) {

        if (i >= part->nelts) {
            if (part->next == NULL) {
                break;
            }

            part = part->next;
            h = part->elts;
            i = 0;
        }

        if (h[i].hash == 0) {
            continue;
        }

        if (!hv->wildcard
            && h[i].key.len == hv->key.len
            && ngx_strncasecmp(h[i].key.data, hv->key.data,
                               h[i].key.len) == 0)
        {
            goto matched;
        }

        if (hv->wildcard
            && h[i].key.len >= hv->key.len - 1
            && ngx_strncasecmp(h[i].key.data, hv->key.data,
                               hv->key.len - 1) == 0)
        {
            goto matched;
        }

        /* not matched */
        continue;

matched:

        if (hv->opcode == ngx_http_headers_control_opcode_add) {
            return NGX_OK;
        }

        if (value->len == 0 || matched) {
            dd("clearing normal header for %.*s", (int) hv->key.len,
               hv->key.data);

            h[i].value.len = 0;
            h[i].hash = 0;

        } else {
            h[i].value = *value;
            h[i].hash = hv->hash;
        }

        if (output_header) {
            *output_header = &h[i];
        }

        matched = 1;
    }

    if (matched){
        return NGX_OK;
    }

    if (hv->opcode == ngx_http_headers_control_opcode_rewrite
        || ((hv->wildcard || no_create) && value->len == 0))
    {
        return NGX_OK;
    }

    /* XXX we still need to create header slot even if the value
     * is empty because some builtin headers like Last-Modified
     * relies on this to get cleared */

append:

    h = ngx_list_push(&r->headers_out.headers);
    if (h == NULL) {
        return NGX_ERROR;
    }

    if (value->len == 0) {
        h->hash = 0;

    } else {
        h->hash = hv->hash;
    }

    h->key = hv->key;
    h->value = *value;
#if defined(nginx_version) && nginx_version >= 1023000
    h->next = NULL;
#endif

    h->lowcase_key = ngx_pnalloc(r->pool, h->key.len);
    if (h->lowcase_key == NULL) {
        return NGX_ERROR;
    }

    ngx_strlow(h->lowcase_key, h->key.data, h->key.len);

    if (output_header) {
        *output_header = h;
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_headers_control_set_builtin_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    ngx_table_elt_t  *h, **old;

    dd_enter();

    if (hv->offset) {
        old = (ngx_table_elt_t **) ((char *) &r->headers_out + hv->offset);

    } else {
        old = NULL;
    }

    if (old == NULL || *old == NULL) {
        if (hv->opcode == ngx_http_headers_control_opcode_rewrite) {
            return NGX_OK;
        }

        return ngx_http_headers_control_set_header_helper(r, hv, value, old, 0);
    }

    if (hv->opcode == ngx_http_headers_control_opcode_add) {
        return NGX_OK;
    }

    h = *old;

    if (value->len == 0) {
        dd("clearing the builtin header");

        h->hash = 0;
        h->value = *value;

        return NGX_OK;
    }

    h->hash = hv->hash;
    h->key = hv->key;
    h->value = *value;

    return NGX_OK;
}


static ngx_int_t
ngx_http_headers_control_set_builtin_multi_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
#if defined(nginx_version) && nginx_version >= 1023000
    ngx_table_elt_t  **headers, *h, *ho, **ph;

    headers = (ngx_table_elt_t **) ((char *) &r->headers_out + hv->offset);

    if (*headers) {
        for (h = (*headers)->next; h; h = h->next) {
            h->hash = 0;
            h->value.len = 0;
        }

        h = *headers;

        h->value = *value;

        if (value->len == 0) {
            h->hash = 0;

        } else {
            h->hash = hv->hash;
        }

        return NGX_OK;
    }

    for (ph = headers; *ph; ph = &(*ph)->next) { /* void */ }

    ho = ngx_list_push(&r->headers_out.headers);
    if (ho == NULL) {
        return NGX_ERROR;
    }

    ho->value = *value;
    ho->hash = hv->hash;
    ngx_str_set(&ho->key, "Cache-Control");
    ho->next = NULL;
    *ph = ho;

    return NGX_OK;
#else
    ngx_array_t      *pa;
    ngx_table_elt_t  *ho, **ph;
    ngx_uint_t        i;

    pa = (ngx_array_t *) ((char *) &r->headers_out + hv->offset);

    if (pa->elts == NULL) {
        if (ngx_array_init(pa, r->pool, 2, sizeof(ngx_table_elt_t *))
            != NGX_OK)
        {
            return NGX_ERROR;
        }
    }

    /* override old values (if any) */

    if (pa->nelts > 0) {
        ph = pa->elts;
        for (i = 1; i < pa->nelts; i++) {
            ph[i]->hash = 0;
            ph[i]->value.len = 0;
        }

        ph[0]->value = *value;

        if (value->len == 0) {
            ph[0]->hash = 0;

        } else {
            ph[0]->hash = hv->hash;
        }

        return NGX_OK;
    }

    ph = ngx_array_push(pa);
    if (ph == NULL) {
        return NGX_ERROR;
    }

    ho = ngx_list_push(&r->headers_out.headers);
    if (ho == NULL) {
        return NGX_ERROR;
    }

    ho->value = *value;
    ho->hash = hv->hash;
    ngx_str_set(&ho->key, "Cache-Control");
    *ph = ho;

    return NGX_OK;
#endif
}


static ngx_int_t
ngx_http_headers_control_set_content_type_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    u_char          *p, *last, *end;

    r->headers_out.content_type_len = value->len;
    r->headers_out.content_type = *value;
    r->headers_out.content_type_hash = hv->hash;
    r->headers_out.content_type_lowcase = NULL;

    p = value->data;
    end = p + value->len;

    for (; p != end; p++) {

        if (*p != ';') {
            continue;
        }

        last = p;

        while (*++p == ' ') { /* void */ }

        if (p == end) {
            break;
        }

        if (ngx_strncasecmp(p, (u_char *) "charset=", 8) != 0) {
            continue;
        }

        p += 8;

        r->headers_out.content_type_len = last - value->data;

        if (*p == '"') {
            p++;
        }

        last = end;

        if (*(last - 1) == '"') {
            last--;
        }

        r->headers_out.charset.len = last - p;
        r->headers_out.charset.data = p;

        break;
    }

    value->len = 0;

    return ngx_http_headers_control_set_header_helper(r, hv, value, NULL, 1);
}


static ngx_int_t
ngx_http_headers_control_set_content_length_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    off_t           len;

    if (value->len == 0) {
        return ngx_http_headers_control_clear_content_length_header(r, hv,
                                                                    value);
    }

    len = ngx_atosz(value->data, value->len);
    if (len == NGX_ERROR) {
        return NGX_ERROR;
    }

    r->headers_out.content_length_n = len;

    return ngx_http_headers_control_set_builtin_header(r, hv, value);
}


static ngx_int_t
ngx_http_headers_control_set_accept_ranges_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    if (value->len == 0) {
        r->allow_ranges = 0;
    }

    return ngx_http_headers_control_set_builtin_header(r, hv, value);
}


static ngx_int_t
ngx_http_headers_control_clear_content_length_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    r->headers_out.content_length_n = -1;

    return ngx_http_headers_control_clear_builtin_header(r, hv, value);
}


static ngx_int_t
ngx_http_headers_control_clear_builtin_header(ngx_http_request_t *r,
    ngx_http_headers_control_header_val_t *hv, ngx_str_t *value)
{
    dd_enter();

    value->len = 0;

    return ngx_http_headers_control_set_builtin_header(r, hv, value);
}


char *
ngx_http_headers_control_output_header(ngx_conf_t *cf,
    ngx_command_t *cmd, void *conf)
{
    return ngx_http_headers_control_parse_directive(cf, cmd, conf,
               ngx_http_headers_control_set_handlers, 0);
}
