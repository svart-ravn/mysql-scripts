#!/bin/bash


PK=id
DB=$1
TABLE=$2


CMD="mysql -BN"

MIN_ID=
MAX_ID

# --------------------------------------------------------------------------------------------------------------
function check_options(){
	return 0
}



function c_mysql(){
	mysql -BN $DB -e "$1"
}


# --------------------------------------------------------------------------------------------------------------
function init(){
	local VAL=$(c_mysql "select min($PK), max($PK) from $TABLE")
	MIN_ID=$(echo $VAL | awk '{print $1}')
	MAX_ID=$(echo $VAL | awk '{print $2}')
}


# ---------------------------------------------- MAIN ----------------------------------------------------------

check_options || exit 1


init

recover


echo "Completed. OK!"
exit 0