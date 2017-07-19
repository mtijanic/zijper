#!/bin/sh

nwndir=$NWNHOME
libdir=`dirname $0`

if [ ! -d $nwndir ]; then
	echo "NWNHOME not set, bailing."
	exit 1
fi

LANG=C java -cp $libdir/nwn-tools.jar:$libdir/nwn-io.jar org.progeeks.nwn.MiniMapExporter -nwn $nwndir $@ 
