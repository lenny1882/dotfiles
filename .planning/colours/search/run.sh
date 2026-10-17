#!/bin/sh

# usage: run.sh
# reruns the tab 33 base search: group set P2, range 0.25, with col_green weighted 4 (red, orange, yellow, green bases) and 10 (blue base)
# needs python3; takes a few minutes with 6 processes per run; writes result_w4.json and result_w10.json next to this script

dir=$(cd -P "$(dirname "$0")" && pwd)
export TMPDIR=$dir
for w in 4 10; do
	GREEN_W=$w python3 -I "$dir/chain.py" "$dir/cols.txt" 0.25 "$dir/result_w$w.json" P2 > "$dir/result_w$w.log" || exit 1
done
