# Shared by the shell checks: counters, ok/bad/skp, check, check_fails, expect/reject, summary.
# POSIX sh, so the colours checks still run under sh and bash --posix.
# Only failures and skips print unless TEST_VERBOSE=1 (run.sh -v sets it).

pass=0 fail=0 skip=0
TEST_VERBOSE=${TEST_VERBOSE:-0}

ok()   { pass=$((pass + 1)); if [ "$TEST_VERBOSE" = 1 ]; then printf '  ok    %s\n' "$1"; fi; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }
skp()  { skip=$((skip + 1)); printf '  skip  %s\n' "$1"; }
head_() { if [ "$TEST_VERBOSE" = 1 ]; then printf '\n%s\n' "$1"; fi; }

check() {
	if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$2', got '$3'"; fi
}

check_fails() {
	desc=$1
	shift
	if ("$@") >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}

expect() { if grep -Eq -- "$3" "$2"; then ok "$1"; else bad "$1 (no match for: $3)"; sed 's/^/        /' "$2"; fi; }
reject() { if grep -Eq -- "$3" "$2"; then bad "$1 (found: $3)"; sed 's/^/        /' "$2"; else ok "$1"; fi; }

summary() {
	printf '%d passed, %d failed' "$pass" "$fail"
	if [ "$skip" -gt 0 ]; then printf ', %d skipped' "$skip"; fi
	printf '\n'
	[ "$fail" -eq 0 ]
}
