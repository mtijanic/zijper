#!/bin/bash

# This script checks for common mistakes and fixes
# things that can be fixed automagically.

modroot=$(dirname $0)

too_long_files=$(find $modroot/{ut*,area,dlg,itp,mod,nss,ssf}/ -maxdepth 1 -iname \*.\* | cut -d'.' -f2 | cut -d'/' -f3- | sort -u | egrep '/.{17,}$')

[ ! -z "$too_long_files" ] && echo -e "Files that are too long:\n$too_long_files" >&2 && exit 1

# check that all areas have their scripts set
( egrep 'On(Enter|Exit|Heartbeat|UserDefined):' area/*.are.yml|fgrep '""' ) && exit 1

exit 0
