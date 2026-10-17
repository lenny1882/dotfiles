# Base set search

The search that produced the bases in `setup/colours.rules.sh` (tab 33 in `../base_set.md`). Kept for reference; nothing in the install or the colours scripts runs it. It is Python, unlike the rest of the repo.

- `chain.py`: the search, as one file. It is the original `chain.py` with the later patches applied in order (fork pool, group sets P2 to P4, shade and muted chains, `col_green` weighting through `GREEN_W`). Usage: `GREEN_W=4 python3 -I chain.py cols.txt 0.25 out.json P2`.
- `cols.txt`: the 24 chromatic colours as they were before the base set work (`colours.sh` at `2a3ef2d`), one `name #hex` per line.
- `run.sh`: the two runs that give the bases. Weight 4 gives the red, orange, yellow and green bases; weight 10 gives the blue base. Purple is not searched: its base is the OKLCH of `#CA78F4`.
- `result_w4.json`, `result_w10.json`: the output of those runs.

Checked 2026-10-17: rerunning gives the OKLCH triples in `colours.rules.sh` to five decimals (the search is deterministic).
