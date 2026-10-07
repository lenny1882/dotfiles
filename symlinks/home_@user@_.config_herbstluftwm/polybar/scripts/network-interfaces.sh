#!/usr/bin/env bash

output=""
for interface in $(route | grep '^default' | grep -o '[^ ]*$'); do
	ip=$(ifconfig | sed -n '/^'"$interface"'/,$p' | grep inet | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | head -1)
	if [[ ${#output} > 0 ]]; then
		output="$output | "
	fi
	output="$output$interface ($ip)"
done
echo $output