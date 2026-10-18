#!/usr/bin/env bash

set -euo pipefail

module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
nginx_source="$module_root/.ci/nginx"
test_output="$module_root/.ci/test-output"
build_jobs="${TEST_BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
mkdir -p "$test_output"
exec > >(tee "$test_output/run.log") 2>&1

configure_args=(
    --prefix="$nginx_source/test-prefix"
    --with-debug
    --with-http_ssl_module
    --with-http_v2_module
    --with-http_realip_module
    --with-http_sub_module
    --with-http_json_module
    --with-stream
    --with-stream_ssl_module
    --with-stream_realip_module
)

if [[ "${TEST_EXPR:-enabled}" == enabled ]]; then
    configure_args+=(--add-module="$module_root/.ci/ngx_expr_module")
    export TEST_NGINX_EXPR=1
fi

dependency_prefix="$module_root/.ci/deps"
make -C "$module_root/.ci/luajit2" -j"$build_jobs" PREFIX="$dependency_prefix"
make -C "$module_root/.ci/luajit2" install PREFIX="$dependency_prefix"
export LUAJIT_INC="$dependency_prefix/include/luajit-2.1"
export LUAJIT_LIB="$dependency_prefix/lib"
module_lualib="$dependency_prefix/share/lua/5.1"
mkdir -p "$module_lualib"
cp -R "$module_root/.ci/lua-resty-core/lib/." "$module_lualib/"
cp -R "$module_root/.ci/lua-resty-lrucache/lib/." "$module_lualib/"
configure_args+=("--with-ld-opt=-Wl,-rpath,$LUAJIT_LIB")
configure_args+=(--add-module="$module_root/.ci/lua-nginx-module")
configure_args+=(--add-module="$module_root/.ci/nginx-eval-module")
configure_args+=(--add-module="$module_root/.ci/echo-nginx-module")
configure_args+=(--add-module="$module_root")

cd "$nginx_source"
sh ./configure "${configure_args[@]}"
make -j"$build_jobs"

export TEST_NGINX_BINARY="$nginx_source/objs/nginx"
export PERL5LIB="$module_root/.ci/test-nginx/lib"
export TMPDIR="$(mktemp -d /tmp/nginx-module-test.XXXXXX)"
export TEST_NGINX_LEAVE=1
export TEST_NGINX_SERVROOT="$TMPDIR/servroot"
collect_logs() {
    find "$TMPDIR" -type f -name '*.log' -exec cp --parents {} "$test_output/" \;
}
trap collect_logs EXIT
if [[ "$(id -u)" == 0 ]]; then
    export TEST_NGINX_GLOBALS="${TEST_NGINX_GLOBALS:-user root;}"
fi
"$TEST_NGINX_BINARY" -V

cd "$module_root"
shopt -s nullglob
tests=()
for test_file in t/*.t; do
    tests+=("$test_file")
done
if (( ${#tests[@]} == 0 )); then
    echo "No tests selected" >&2
    exit 1
fi
prove -v "${tests[@]}"
