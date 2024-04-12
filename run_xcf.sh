#!/bin/bash

# This script attempts to run a Genero program using the enviroment and location
# taken from a .xcf file. 
# xcf_run.sh crontest testdb
# This example would look for crontest.xcf and run the program passing 'testdb' as 
# a parameter.
# NOTE: This script does not set any database environment
# NOTE: This script ignore <PARAMETER> nodes in the .xcf file
# NOTE: This script only 'translates' $(res.deployment.path), $(sep) and $FGLRUN - other variables 
#       will not be exanded.

GENVER=${GENVER:-321}
GENEROPATH=/opt/fourjs
if [ ! -e $GENEROPATH/fgl$GENVER ]; then
	GENEROPATH=/opt/Genero
fi

source $GENEROPATH/fgl$GENVER/envcomp
source $GENEROPATH/gas$GENVER/envas
APPDATA=$GENEROPATH/gas${GENVER}_appdata
XCF=$1.xcf
shift

if [ ! -e $APPDATA/app/$XCF ]; then
	echo "XCF $XCF not found in $APPDATA/app"
	exit 1
fi

DEPLOY=$(grep \"res.deployment.name $APPDATA/app/$XCF | cut -d'>' -f2 | cut -d'<' -f1)
MODPATH=$(grep "<PATH>" $APPDATA/app/$XCF | cut -d'>' -f2 | cut -d'<' -f1)
MODULE=$(grep "<MODULE>" $APPDATA/app/$XCF | cut -d'>' -f2 | cut -d'<' -f1)
echo "MODPATH=$MODPATH"
if [ ! -z "$MODPATH" ]; then
	MODPATH=$(echo $MODPATH | cut -d')' -f2)
fi
echo "MODPATH=$MODPATH"

APP_PATH=$APPDATA/deployment/$DEPLOY/$MODPATH

IFS=$'\n'
for e in $(grep "ENVIRONMENT_VARIABLE Id" $APPDATA/app/$XCF | cut -d'=' -f2); do
	EN=$(echo $e | cut -d'"' -f2)
	EV=$(echo $e | cut -d'>' -f2 | cut -d'<' -f1 | sed "s#\$(res.deployment.path)#$APP_PATH#g" | sed "s#\$FGLRUN#$FGLRUN#g" | sed "s#\$(sep)#/#g" )
	echo "$EN=$EV"
	export $EN=$EV
done

echo "Attemping to run from $APPDATA/app/$XCF in $APP_PATH : fglrun $MODULE $*"
cd $APP_PATH
fglrun $MODULE $*
