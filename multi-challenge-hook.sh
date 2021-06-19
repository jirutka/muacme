#!/bin/sh
set -u

for hook in $MUACME_CHALLENGE_HOOKS; do
	if [ "${MUACME_DEBUG:-0}" -eq 1 ]; then
		echo "running $hook" >&2
	fi
	$hook "$@" && exit 0
done
