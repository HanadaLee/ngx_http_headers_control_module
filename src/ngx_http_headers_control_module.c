
/*
 * Copyright (C) Yichun Zhang (agentzh)
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#include "ngx_http_headers_control_module.h"
#include "ngx_http_headers_control_headers_out.h"
#include "ngx_http_headers_control_headers_in.h"
#include "ngx_http_headers_control_util.h"
#include <ngx_config.h>


/* config handlers */

static void *ngx_http_headers_control_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_headers_control_merge_loc_conf(ngx_conf_t *cf,
    void *parent, void *child);
static void *ngx_http_headers_control_create_main_conf(ngx_conf_t *cf);
static ngx_int_t ngx_http_headers_control_post_config(ngx_conf_t *cf);

/* rewrite-phase handler */

static ngx_int_t ngx_http_headers_control_handler(ngx_http_request_t *r);

/* filter handlers */

static ngx_int_t ngx_http_headers_control_filter_init(ngx_conf_t *cf);

ngx_uint_t  ngx_http_headers_control_location_hash = 0;


static ngx_command_t  ngx_http_headers_control_filter_commands[] = {

    { ngx_string("response_header_control"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF
                        |NGX_CONF_2MORE,
      ngx_http_headers_control_output_header,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("request_header_control"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF
                        |NGX_CONF_2MORE,
      ngx_http_headers_control_input_header,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

      ngx_null_command
};


static ngx_http_module_t  ngx_http_headers_control_module_ctx = {
    NULL,                                          /* preconfiguration */
    ngx_http_headers_control_post_config,          /* postconfiguration */

    ngx_http_headers_control_create_main_conf,     /* create main conf */
    NULL,                                          /* init main conf */

    NULL,                                          /* create server conf */
    NULL,                                          /* merge server conf */

    ngx_http_headers_control_create_loc_conf,      /* create location conf */
    ngx_http_headers_control_merge_loc_conf        /* merge location conf */
};


ngx_module_t  ngx_http_headers_control_module = {
    NGX_MODULE_V1,
    &ngx_http_headers_control_module_ctx,          /* module context */
    ngx_http_headers_control_filter_commands,      /* module directives */
    NGX_HTTP_MODULE,                               /* module type */
    NULL,                                          /* init master */
    NULL,                                          /* init module */
    NULL,                                          /* init process */
    NULL,                                          /* init thread */
    NULL,                                          /* exit thread */
    NULL,                                          /* exit process */
    NULL,                                          /* exit master */
    NGX_MODULE_V1_PADDING
};


static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;


static volatile ngx_cycle_t  *ngx_http_headers_control_prev_cycle = NULL;


static ngx_int_t
ngx_http_headers_control_filter(ngx_http_request_t *r)
{
    ngx_int_t                               rc;
    ngx_uint_t                              i, j;
    ngx_http_headers_control_loc_conf_t    *conf;
    ngx_http_headers_control_header_val_t  *h;
    ngx_http_headers_control_bitmap_t       locked;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "headers control header filter, uri \"%V\"", &r->uri);

    conf = ngx_http_get_module_loc_conf(r, ngx_http_headers_control_module);

    if (conf->headers_out == NULL) {
        return ngx_http_next_header_filter(r);
    }

    h = conf->headers_out->elts;

    ngx_http_headers_control_bitmap_init(&locked, conf->headers_out_cnt,
                                         r->pool);

    for (i = 0; i < conf->headers_out->nelts; i++) {

        /* wildcard rules always execute, no locking checks */
        if (!h[i].wildcard) {

            /* exact rule: check if locked by a previous exact rule */
            for (j = 0; j < i; j++) {
                if (h[j].wildcard) {
                    continue;
                }

                if (h[j].key.len == h[i].key.len
                    && ngx_strncasecmp(h[j].key.data, h[i].key.data,
                                       h[i].key.len) == 0
                    && ngx_http_headers_control_bitmap_isset(&locked,
                                                             h[j].id))
                {
                    break;
                }
            }

            if (j < i) {
                continue;
            }
        }

        rc = ngx_http_headers_control_exec_output_header(r, &h[i], &locked);

        if (rc == NGX_ERROR) {
            return rc;
        }

        if (rc == NGX_DECLINED) {
            continue;
        }

        /* update locked state (exact rules only, wildcard never locks) */
        if (!h[i].wildcard && !h[i].next) {
            locked.bits[h[i].id / NGX_INT_T_LEN]
                |= (ngx_uint_t) 1 << (h[i].id % NGX_INT_T_LEN);
        }
    }

    return ngx_http_next_header_filter(r);
}


static ngx_int_t
ngx_http_headers_control_filter_init(ngx_conf_t *cf)
{
    ngx_http_next_header_filter = ngx_http_top_header_filter;
    ngx_http_top_header_filter = ngx_http_headers_control_filter;

    return NGX_OK;
}


static void *
ngx_http_headers_control_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_headers_control_loc_conf_t    *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_headers_control_loc_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    /*
     * set by ngx_pcalloc():
     *
     *     conf->headers_in = NULL;
     *     conf->headers_out = NULL;
     */

    return conf;
}


static void
ngx_http_headers_control_merge_one_array(ngx_conf_t *cf,
    ngx_array_t **curr_headers, ngx_array_t *prev_headers,
    ngx_uint_t *curr_cnt, ngx_uint_t prev_cnt)
{
    ngx_uint_t                              i, j;
    ngx_uint_t                              orig_len, prev_len, copy_count, pos;
    ngx_http_headers_control_header_val_t  *prev_h, *h;
    ngx_http_headers_control_bitmap_t       disable_map;

    orig_len = (*curr_headers)->nelts;
    prev_len = prev_headers->nelts;

    h = (*curr_headers)->elts;
    prev_h = prev_headers->elts;

    ngx_http_headers_control_bitmap_init(&disable_map, prev_cnt, cf->pool);

    /*
     * Child exact rule (no filter, no -n) → disable parent exact rule
     * with the same header name. Wildcard rules and exact rules with
     * filter or -n never disable parent rules.
     */
    for (i = 0; i < orig_len; i++) {

        if (h[i].filter || h[i].next || h[i].wildcard) {
            continue;
        }

        for (j = 0; j < prev_len; j++) {
            if (!prev_h[j].wildcard
                && h[i].key.len == prev_h[j].key.len
                && ngx_strncasecmp(h[i].key.data, prev_h[j].key.data,
                                   h[i].key.len) == 0)
            {
                ngx_http_headers_control_bitmap_set(&disable_map,
                                                    prev_h[j].id);
            }
        }
    }

    copy_count = 0;
    for (j = 0; j < prev_len; j++) {
        if (!ngx_http_headers_control_bitmap_isset(&disable_map,
                                                   prev_h[j].id))
        {
            copy_count++;
        }
    }

    if (copy_count > 0) {
        (void) ngx_array_push_n(*curr_headers, copy_count);

        h = (*curr_headers)->elts;

        /* append non-disabled parent rules after child rules */
        pos = orig_len;
        for (j = 0; j < prev_len; j++) {
            if (!ngx_http_headers_control_bitmap_isset(&disable_map,
                                                       prev_h[j].id))
            {
                h[pos++] = prev_h[j];
            }
        }
    }

    for (i = 0; i < (*curr_headers)->nelts; i++) {
        h[i].id = i;
    }

    *curr_cnt = (*curr_headers)->nelts;
}


static char *
ngx_http_headers_control_merge_loc_conf(ngx_conf_t *cf, void *parent,
    void *child)
{
    ngx_http_headers_control_loc_conf_t     *prev = parent;
    ngx_http_headers_control_loc_conf_t     *conf = child;

    if (conf->headers_out == NULL || conf->headers_out->nelts == 0) {
        conf->headers_out = prev->headers_out;
        conf->headers_out_cnt = prev->headers_out_cnt;

    } else if (prev->headers_out && prev->headers_out->nelts) {
        ngx_http_headers_control_merge_one_array(cf,
            &conf->headers_out, prev->headers_out,
            &conf->headers_out_cnt, prev->headers_out_cnt);
    }

    if (conf->headers_in == NULL || conf->headers_in->nelts == 0) {
        conf->headers_in = prev->headers_in;
        conf->headers_in_cnt = prev->headers_in_cnt;

    } else if (prev->headers_in && prev->headers_in->nelts) {
        ngx_http_headers_control_merge_one_array(cf,
            &conf->headers_in, prev->headers_in,
            &conf->headers_in_cnt, prev->headers_in_cnt);
    }

    return NGX_CONF_OK;
}


static ngx_int_t
ngx_http_headers_control_post_config(ngx_conf_t *cf)
{
    int                              multi_http_blocks;
    ngx_int_t                        rc;
    ngx_http_handler_pt             *h;
    ngx_http_core_main_conf_t       *cmcf;

    ngx_http_headers_control_main_conf_t       *hmcf;

    ngx_http_headers_control_location_hash =
                             ngx_http_headers_control_hash_literal("location");

    hmcf = ngx_http_conf_get_module_main_conf(cf,
                                              ngx_http_headers_control_module);

    if (ngx_http_headers_control_prev_cycle != ngx_cycle) {
        ngx_http_headers_control_prev_cycle = ngx_cycle;
        multi_http_blocks = 0;

    } else {
        multi_http_blocks = 1;
    }

    if (multi_http_blocks || hmcf->requires_filter) {
        rc = ngx_http_headers_control_filter_init(cf);
        if (rc != NGX_OK) {
            return rc;
        }
    }

    if (!hmcf->requires_handler) {
        return NGX_OK;
    }

    cmcf = ngx_http_conf_get_module_main_conf(cf, ngx_http_core_module);

    h = ngx_array_push(&cmcf->phases[NGX_HTTP_REWRITE_PHASE].handlers);
    if (h == NULL) {
        return NGX_ERROR;
    }

    *h = ngx_http_headers_control_handler;

    return NGX_OK;
}


static ngx_int_t
ngx_http_headers_control_handler(ngx_http_request_t *r)
{
    ngx_int_t                               rc;
    ngx_uint_t                              i, j;
    ngx_http_headers_control_loc_conf_t    *conf;
    ngx_http_headers_control_main_conf_t   *hmcf;
    ngx_http_headers_control_header_val_t  *h;
    ngx_http_headers_control_bitmap_t       locked;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "headers control rewrite handler, uri \"%V\"", &r->uri);

    hmcf = ngx_http_get_module_main_conf(r,
                                         ngx_http_headers_control_module);

    if (!hmcf->postponed_to_phase_end) {
        ngx_http_core_main_conf_t       *cmcf;
        ngx_http_phase_handler_t         tmp;
        ngx_http_phase_handler_t        *ph;
        ngx_http_phase_handler_t        *cur_ph;
        ngx_http_phase_handler_t        *last_ph;

        hmcf->postponed_to_phase_end = 1;

        cmcf = ngx_http_get_module_main_conf(r, ngx_http_core_module);

        ph = cmcf->phase_engine.handlers;
        cur_ph = &ph[r->phase_handler];
        last_ph = &ph[cur_ph->next - 1];

        if (cur_ph < last_ph) {
            dd("swaping the contents of cur_ph and last_ph...");

            tmp = *cur_ph;

            memmove(cur_ph, cur_ph + 1,
                    (last_ph - cur_ph) * sizeof (ngx_http_phase_handler_t));

            *last_ph = tmp;

            r->phase_handler--; /* redo the current ph */

            return NGX_DECLINED;
        }
    }

    dd("running phase handler...");

    conf = ngx_http_get_module_loc_conf(r, ngx_http_headers_control_module);

    if (conf->headers_in == NULL) {
        return NGX_DECLINED;
    }

    if (r->http_version < NGX_HTTP_VERSION_10) {
        return NGX_DECLINED;
    }

    h = conf->headers_in->elts;

    ngx_http_headers_control_bitmap_init(&locked, conf->headers_in_cnt,
                                         r->pool);

    for (i = 0; i < conf->headers_in->nelts; i++) {

        /* wildcard rules always execute, no locking checks */
        if (!h[i].wildcard) {
            /* exact rule: check if locked by a previous exact rule */
            for (j = 0; j < i; j++) {
                if (h[j].wildcard) {
                    continue;
                }

                if (h[j].key.len == h[i].key.len
                    && ngx_strncasecmp(h[j].key.data, h[i].key.data,
                                       h[i].key.len) == 0
                    && ngx_http_headers_control_bitmap_isset(&locked,
                                                             h[j].id))
                {
                    break;
                }
            }

            if (j < i) {
                continue;
            }
        }

        rc = ngx_http_headers_control_exec_input_header(r, &h[i], &locked);

        if (rc == NGX_ERROR) {
            return rc;
        }

        if (rc == NGX_DECLINED) {
            continue;
        }

        /* update locked state (exact rules only, wildcard never locks) */
        if (!h[i].wildcard && !h[i].next) {
            locked.bits[h[i].id / NGX_INT_T_LEN]
                |= (ngx_uint_t) 1 << (h[i].id % NGX_INT_T_LEN);
        }
    }

    return NGX_DECLINED;
}


static void *
ngx_http_headers_control_create_main_conf(ngx_conf_t *cf)
{
    ngx_http_headers_control_main_conf_t    *hmcf;

    hmcf = ngx_pcalloc(cf->pool, sizeof(ngx_http_headers_control_main_conf_t));
    if (hmcf == NULL) {
        return NULL;
    }

    /* set by ngx_pcalloc:
     *      hmcf->postponed_to_phase_end = 0;
     *      hmcf->requires_filter        = 0;
     *      hmcf->requires_handler       = 0;
     */

    return hmcf;
}
