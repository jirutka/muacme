#!/bin/sh
# This script is executed after at least one certificate has been successfully
# renewed. It will get domain names of the renewed certificate (only CN, not
# alternative names) as arguments.
set -eu

# Replace this with a command to reload web server or other service(s) that
# use certificates managed by muacme.
exit 0
