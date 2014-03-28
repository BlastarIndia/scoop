#!/bin/sh
# get-scoop.sh
# By Dylan Griffiths <Inoshiro@kuro5hin.org>
# Gets you the latest snapshot of Scoop with one command.
# Warning: You need CVS installed and in the current path.
# This script assumes that it is installed in ${scoop_root}/scripts

scripts="`dirname $0`"
[ "${scripts}" = "." ] && scripts="`pwd`"
scoop_root="`dirname ${scripts}`"

if [ "`basename ${scripts}`" = "scripts" -a -f ${scoop_root}/VERSION ] ; then
	cd ${scoop_root}
	cvs -z3 -d:pserver:anonymous@scoop.versionhost.com:/cvs/scoop update
else
	cat << ERRORMSG
ERROR: $0 must be run from the \${scoop_root}/scripts
ERROR: directory.  (It needs to be able to find the CVS tree.)

ERRORMSG
	exit 1
fi

