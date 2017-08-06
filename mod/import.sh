#!/bin/bash

# This script imports game resources into their proper
# directories within the mod structure, converting them
# appropriately.

modroot=$(dirname $0)

run() {
	echo "$@"
	$@
}

for x in $@; do
	target=""
	opts=""
	ext=`echo $x | tr "[:upper:]" "[:lower:]"`
	case $ext in
	*.ut[a-z]) target=${ext:(-3):3} ;;
	*.are) target="area" ;;
	*.git) target="area" ;;
	*.gic) target="area" ;;
	*.dlg) target="dlg" ;;
	*.ssf) target="ssf" ;;
	*.itp) target="itp" ;;
	*.fac) target="mod" ;;
	*.ifo) target="mod" ;;
	*.jrl) target="mod" ;;
	*.nss) continue; ;;
	*.ncs) continue; ;;
	*)
		echo "WARNING: Cannot place $x; skipping."
		continue
		;;
	esac

	base=`basename $x | tr "[:upper:]" "[:lower:]"`
	to="$modroot/$target/$base"
	to_yml="$to.yml"

	if [ -f $to ]; then
		x_md=`md5sum $x|cut -d' ' -f1`
		to_md=`md5sum $to|cut -d' ' -f1`
		if [ "$x_md" = "$to_md" ]; then
			echo "Not importing $x: not modified."
			continue
		fi
	fi

	run nwn-gff $($modroot/nwn-lib-import-filters.sh) -i $x -ky -o $to_yml
done
