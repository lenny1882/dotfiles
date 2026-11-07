#!/usr/bin/env bash
# usage: tests/run.sh [-v]
# Runs every check and prints one line per suite; a failing suite also prints its failures.
# -v lists every single check.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
[[ ${1:-} == -v ]] && export TEST_VERBOSE=1

failed=0 total=0

suite() {
    local label=$1 out rc
    shift
    out=$("$@" 2>&1)
    rc=$?
    total=$((total + 1))
    printf '%-30s %s\n' "$label" "$(tail -n 1 <<<"$out")"
    if ((rc != 0)); then
        failed=$((failed + 1))
        sed '$d; s/^/    /' <<<"$out"
    elif [[ ${TEST_VERBOSE:-0} == 1 ]]; then
        sed '$d; s/^/    /' <<<"$out"
    fi
}

suite "colours_check (sh)"           sh colours_check.sh
suite "colours_check (bash)"         bash colours_check.sh
suite "colours_check (bash --posix)" bash --posix colours_check.sh
suite "colours_gen_check (sh)"       sh colours_gen_check.sh
suite "colours_gen_check (bash)"     bash colours_gen_check.sh
suite "monitor_check"                bash monitor_check.sh

if ((failed == 0)); then
    echo "all $total suites passed"
else
    echo "$failed of $total suites failed"
    exit 1
fi
