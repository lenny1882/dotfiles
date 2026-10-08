#!/usr/bin/env bash

output=""
for interface in $(ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1)}'); do
	ip=$(ip -4 -o addr show dev "$interface" | awk '{split($4, a, "/"); print a[1]; exit}')
	if [[ ${#output} > 0 ]]; then
		output="$output | "
	fi
	output="$output$interface ($ip)"
done
echo $output