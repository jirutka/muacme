#!/bin/sh
# This is a uacme hook script for challenge type http-01 that automatically
# starts busybox httpd server on port 80 to serve the key authorization for the
# challenge verification and stops it when it's done.
#
# This file is part of muacme.
set -eu

PROGNAME=$(basename "$0")

HTTP_BASE_DIR='/tmp/uacme-challenge'
CHALLENGE_DIR="$HTTP_BASE_DIR/.well-known/acme-challenge"
PIDFILE='/run/uacme-httpd.pid'

if [ $# -ne 5 ]; then
	echo "Usage: $PROGNAME (begin | done | failed) http-01 <ident> <token> <auth>" >&2
	exit 85  # copied from uacme.sh
fi

method=$1
type=$2
ident=$3
token=$4
auth=$5

if [ "$type" != 'http-01' ]; then
	echo "$PROGNAME: unsupported type: $type" >&2
	exit 1
fi

case "$method" in
	begin)
		mkdir -p "$CHALLENGE_DIR"

		start-stop-daemon \
			--start \
			--background \
			--make-pidfile \
			--pidfile "$PIDFILE" \
			--stderr-logger 'logger -t muacme -p cron.err' \
			-- httpd -f -u nobody:nogroup -h "$HTTP_BASE_DIR" || true

		printf '%s' "$auth" > "$CHALLENGE_DIR/$token"
	;;
	done | failed)
		rm "$CHALLENGE_DIR/$token"

		start-stop-daemon --stop --pidfile "$PIDFILE" || true
	;;
	*)
		echo "$PROGNAME: invalid method: $method" >&2
		exit 1
	;;
esac
