#!/bin/sh
# This is a uacme hook script for the challenge type dns-01 that utilizes
# acme-dns server to add _acme-challenge.<domain> TXT record for the requested
# domain name. See muacme.conf for configuration options.
#
# This file is part of muacme.
set -eu

readonly PROGNAME=$(basename "$0")

if ( set -o pipefail 2>/dev/null ); then
	set -o pipefail
else
	echo "$PROGNAME: ERROR: your shell does not support option pipefail!" >&2
	exit 1
fi


die() {
	echo "$*" >&2
	exit 1
}

lookup_cname_for() {
	set -- $($DNS01_DIG ${DNS01_DEBUG:+-d} +noall +answer "$1" CNAME | grep 'IN\s*CNAME\s')
	[ "${5-}" ] || return 1

	echo "${5%.}"
}

http_post() {
	local url="$1"
	local keypass="$2"
	local data="$3"

	wget -q -O - \
		-U 'muacme' \
		-T "$DNS01_WAIT_MAX" \
		${DNS01_DEBUG:+-S} \
		--header 'Content-Type:application/json' \
		--header "X-Api-User:${keypass%%:*}" \
		--header "X-Api-Key:${keypass#*:}" \
		--post-data "$data" \
		"$url"
}


if [ $# -ne 5 ]; then
	echo "Usage: $PROGNAME (begin | done | failed) dns-01 <ident> <token> <auth>" >&2
	exit 85  # copied from uacme.sh
fi

readonly METHOD=$1
readonly TYPE=$2
readonly IDENT=$3
readonly AUTH=$5

{
	[ "$TYPE" = 'dns-01' ] \
		|| die "unsupported type: $TYPE"

	case "$METHOD" in
		begin) ;;  # continue
		done | failed) exit 0;;  # nothing to be done
		*) die "invalid method: $METHOD";;
	esac

	: ${MUACME_CONFIG:="/etc/muacme/muacme.conf"}

	[ -r "$MUACME_CONFIG" ] \
		|| die "config '$MUACME_CONFIG' does not exist or is not readable!"
	. "$MUACME_CONFIG" \
		|| die "failed to source config $MUACME_CONFIG!"

	: ${DNS01_ACMEDNS_KEYS:=${dns01_acmedns_keys:-"/etc/muacme/acme-dns.keys"}}
	: ${DNS01_DIG:=${dns01_dig:-"kdig +timeout=5 +retry=3"}}
	: ${DNS01_WAIT_MAX:=${dns01_wait_max:-10}}
	: ${DNS01_DEBUG:=${dns01_debug:-}}

	[ -f "$DNS01_ACMEDNS_KEYS" ] \
		|| die "file $DNS01_ACMEDNS_KEYS does not exist or not readable"

	cname="$(lookup_cname_for "_acme-challenge.$IDENT")" \
		|| die "failed to resolve CNAME for _acme-challenge.$IDENT"

	acmedns_url="https://${cname#*.}"
	subdomain="${cname%%.*}"

	userkey=$(sed -En "s/^$subdomain:([^ :]+):([^ #]+).*/\1:\2/p" "$DNS01_ACMEDNS_KEYS" | grep .) \
		|| die "no user and key found for subdomain $subdomain ($IDENT)"

	http_post "$acmedns_url/update" \
		"$userkey" \
		"{\"subdomain\":\"$subdomain\", \"txt\":\"$AUTH\"}" \
		|| die "failed to update acme-dns $cname for $IDENT"

} 2>&1 | sed "s/^;; //;s/^/$PROGNAME: /" >&2
