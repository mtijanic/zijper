#!/bin/sh

set -e

TA=$1

REV=`svn info --non-interactive $TA | grep Revision | cut -d " " -f 2`
DATE=`svn info --non-interactive $TA | grep 'Last Changed Date' | cut -d " " -f 4-`
ROOT=`svn info --non-interactive $TA | grep 'Repository Root' | cut -d " " -f 3-`

BUILDDATE=`date "+%Y-%m-%d %X %z (%a, %d %b %Y)"`
if [ -z $REV ]; then
	echo "Cannot get revision, bailing."
	exit 1
fi

echo -n "" >_buildinfo.nss
echo "const string PROJECT = \"Silbermarken\";" >> _buildinfo.nss
echo "const string REVISION = \""$REV"\";" >>_buildinfo.nss
echo "const string REPOSITORY = \""$ROOT"\";" >>_buildinfo.nss
echo "const string COMMIT_ON = \""$DATE"\";" >>_buildinfo.nss
echo "const string BUILD_ON = \""$BUILDDATE"\";" >>_buildinfo.nss

exit 0
