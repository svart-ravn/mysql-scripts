#!/bin/bash


PK=id
DB=$1
TABLE=$2


MIN_ID=
MAX_ID=

MYSQL_CMD="mysql $DB -BN"

# --------------------------------------------------------------------------------------------------------------
function check_options(){
   return 0
}



# --------------------------------------------------------------------------------------------------------------
function error(){
   >&2 echo "[ERR]:  $1"
}


function info(){
   echo "[INFO]: $1"
}


# --------------------------------------------------------------------------------------------------------------
function wait_for_mysql(){
   local RC=1
   while [ RC -eq 1 ]; do
      $MYSQL_CMD -e "select 1" >/dev/null
      RC=$?
      error "Waiting for MySQL to be started...."
      sleep 1
   done

   return 0
}


# --------------------------------------------------------------------------------------------------------------
function init(){
   VAL=$($MYSQL_CMD -e "select min($PK), max($PK) from $TABLE" 2>/dev/null)
   if [ $? -ne 0 ]; then
      error "Cannot connect or cannot find database/table to perform check. Exiting..."
      return 1
   fi

   MIN_ID=$(echo $VAL | awk '{print $1}')
   MAX_ID=$(echo $VAL | awk '{print $2}')
   info "min_id=$MIN_ID, max_id=$MAX_ID"

   return 0
}


function recover(){
   return 0
}

# ---------------------------------------------- MAIN ----------------------------------------------------------

check_options || exit 1


init


recover


echo "Completed. OK!"

exit 0