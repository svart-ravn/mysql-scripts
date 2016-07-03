#!/bin/bash


PK=id
DB=$1
TABLE=$2
DEST_TABLE="recovered_${TABLE}"


MIN_ID=
MAX_ID=

MYSQL_CMD="mysql $DB -BN"


# --------------------------------------------------------------------------------------------------------------
function check_options(){
   if [ -z "$DB" ]; then
      error "Use \$1 to pass DB name"
      return 1
   fi
   
   if [ -z "$TABLE" ]; then
      error "Use \$2 to pass table name"
      return 1
   fi

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
   while [ $RC -eq 1 ]; do
      $MYSQL_CMD -e "select 1" >/dev/null 2>&1
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


   $MYSQL_CMD -e "drop table if exists $DEST_TABLE"
   $MYSQL_CMD -e "create table if not exists $DEST_TABLE like $TABLE"

   return 0
}


function recover(){
   for ID in $(seq $MIN_ID $MAX_ID); do 

      $MYSQL_CMD -e "insert into $DEST_TABLE select * from $TABLE where $PK=$ID" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
         info "$ID is ok"
      else
         error "$ID is not migrated"
         wait_for_mysql
      fi
   done

   return 0
}


# ---------------------------------------------- MAIN ----------------------------------------------------------
check_options || exit 1


init || exit 1


info "Starting recovery..."
recover


echo "Completed. OK!"

exit 0