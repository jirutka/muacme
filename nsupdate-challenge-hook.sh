#!/bin/sh
# This is a uacme hook script for the challenge type dns-01 that utilizes
# (k)nsupdate to add/delete _acme-challenge.<domain> TXT record for the
# requested domain name. See muacme.conf for configuration options.
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

_dig() {
	$DNS01_DIG ${DNS01_DEBUG:+-d} +nocomments +nomultiline "$@"
}

lookup_soa_for() {
	_dig +noall +authority "$1" SOA
}

lookup_txt_rdata() {
	local fqdn=$1
	local nameserver=$2
	local out

	out=$(_dig +short "$fqdn" TXT "@$nameserver")
	out=${out%\"}
	out=${out#\"}

	printf %s "$out"
}

wait_for_txt_match() {
	local fqdn=$1
	local expected=$2
	local nameserver=$3
	local start_time=$(date +%s)
	local actual

	while [ $(date +%s) -lt $(($start_time + $DNS01_WAIT_MAX)) ]; do
		actual=$(lookup_txt_rdata "$fqdn" "$nameserver")
		[ "$actual" = "$expected" ] && return 0
		sleep 1
	done

	return 1
}

update_record() {
	local zone=$1; shift
	local keyopt

	case "$DNS01_DDNS_KEY" in
		/*) keyopt="-k $DNS01_DDNS_KEY";;  # file path
		*) keyopt="-y $DNS01_DDNS_KEY";;  # [<alg>:]<name>:<key>
	esac

	$DNS01_NSUPDATE ${DNS01_DEBUG:+-d} $keyopt <<-EOF
		server $DNS01_DDNS_SERVER
		zone $zone
		update $*
		send
	EOF
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

	: ${MUACME_CONFIG:="/etc/muacme/muacme.conf"}

	[ -r "$MUACME_CONFIG" ] \
		|| die "config '$MUACME_CONFIG' does not exist or is not readable!"
	. "$MUACME_CONFIG" \
		|| die "failed to source config $MUACME_CONFIG!"

	: ${DNS01_DDNS_KEY:=${dns01_ddns_key}}
	: ${DNS01_DIG:=${dns01_dig:-"kdig +timeout=5 +retry=3"}}
	: ${DNS01_NSUPDATE:=${dns01_nsupdate:-"knsupdate -t 5 -r 3 -v"}}
	: ${DNS01_WAIT_MAX:=${dns01_wait_max:-10}}
	: ${DNS01_DEBUG:=${dns01_debug:-}}

	fqdn="_acme-challenge.$IDENT"

	soa=$(lookup_soa_for "$fqdn") \
		|| die "failed to resolve SOA for $fqdn"
	nameserver=$(set -- $soa; echo $5)
	zone=$(set -- $soa; echo $1)

	: ${DNS01_DDNS_SERVER:=${dns01_ddns_server:-$nameserver}}

	case "$METHOD" in
		begin)
			update_record "$zone" add "$fqdn." TXT "$AUTH" \
				|| die "failed to add record $fqdn via $DNS01_DDNS_SERVER"

			wait_for_txt_match "$fqdn" "$AUTH" "$nameserver" \
				|| die "record update for $fqdn sent to $DNS01_DDNS_SERVER, but with no effect on $nameserver"
		;;
		done | failed)
			update_record "$zone" delete "$fqdn." TXT \
				|| die "failed to delete $fqdn record via $DNS01_DDNS_SERVER"
		;;
		*)
			die "invalid method: $METHOD"
		;;
	esac
} 2>&1 | sed "s/^;; //;s/^/$PROGNAME: /" >&2
