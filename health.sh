#!/bin/bash

COLOR_NO="\e[0m"
COLOR_ERR="\e[0;31m"
COLOR_OK="\e[0;32m"

HEADER="%-20s %s\n"

# --------------- MYSQL status ------------------------------------

function is_running(){
   mysql -e "select 1" &>/dev/null
   if [ $? -eq 0 ]; then
      echo "mysql is running"
      return 0
   else
      MYSQL_PATH=$(whereis mysql)
      if [ -z "$MYSQL_PATH" -eq 6 ]; then
         echo -"mysql was not installed"
      else
         echo -e "mysql is stopped"
      fi
      return 1
   fi
}


function master_status(){
   MASTER_STATUS=`mysql -e "show master status\G"`
   if [ ! -z "$MASTER_STATUS" ]; then
      LIST_OF_SLAVES=`mysql -BN -e "select substring_index(host, ':', 1) from information_schema.processlist where command = 'Binlog Dump'"`
      test -z "$LIST_OF_SLAVES" && echo "MASTER (writes binlog)" || printf "$HEADER" "MASTER (writes binlog)"  "slaves: `echo $LIST_OF_SLAVES | tr '\n' ', ' | sed 's/.$//'`"
   else
      echo -e "${COLOR_ERR}Binary logging is not enabled$COLOR_NO"
   fi
}


function slave_status(){
   SLAVE_STATUS=`mysql -e "show slave status\G"`
   if [ ! -z "$SLAVE_STATUS" ]; then
      SQL_THREAD=`echo "$SLAVE_STATUS" | grep -w Slave_SQL_Running | awk '{print $2}'`
      IO_THREAD=`echo "$SLAVE_STATUS" | grep -w Slave_IO_Running | awk '{print $2}'`
      LAG=`echo "$SLAVE_STATUS" | grep -w Seconds_Behind_Master | awk '{print $2}'`
      MASTER_HOST=`echo "$SLAVE_STATUS" | grep -w Master_Host | awk '{print $2}'`

      LAST_IO_ERROR=`echo "$SLAVE_STATUS" | grep -w Last_IO_Error | awk -F ":" '{print $2}' | sed -e 's/^ *//'`
      LAST_SQL_ERROR=`echo "$SLAVE_STATUS" | grep -w Last_SQL_Error | awk -F ":" '{print $2}' | sed -e 's/^ *//'`
      test ! -z "$LAST_IO_ERROR" && MSG="IO error: $LAST_IO_ERROR"
      test ! -z "$LAST_SQL_ERROR" && MSG="$MSG SQL error: $LAST_SQL_ERROR"

      printf "$HEADER" "SLAVE" "sql thread=$SQL_THREAD, io_thread=$IO_THREAD, lag=$LAG, master=$MASTER_HOST ($MSG)"
   fi
}


function processlist_status(){
   LIST_OF_PROCESS="`mysql -BN -e "select group_concat(v.f separator ', ') from ( select concat(user, ': ', count(1)) f from information_schema.processlist group by user) v"`"
   NON_SYSTEM_PROCESS_COUNT=`mysql -BN -e "select count(1) from information_schema.processlist where user not in ('root', 'system user')"`
   printf "$HEADER" "processlist:" "`echo $LIST_OF_PROCESS | tr '\n' ',' | sed -e 's/.$//' -e 's/,/, /g'`"
}


function show_databases(){
   DATABASES="`mysql -BN -e 'show databases' | grep -v -E 'mysql|schema$'`"
   DATABASES=`sudo -u mysql du -h "$DATADIR" | sort -hr | grep "$DATABASES" | awk -F "[/\t]" '{if(length(DB)>0)DB=DB ", "; DB=DB $(NF) ": " $1}END{print DB}'`

   printf "$HEADER" "databases:" "$DATABASES"
}


# --------------- SYS status ------------------------------------
function get_last_modified_file(){
   local THRESHOLD_LEVEL_SEC=604800
   local FOLDER="$1"
   local FILE="$3"
   test -z "$FILE" && FILE="."

   LAST_MODIFIED_FILE=`sudo -u mysql ls -lt "$FOLDER" | grep $FILE | grep -v -e '^d' -e '^total'  | awk '{print $9}' | head -1`
   DIFF=$(($(date +%s)-$(sudo -u mysql stat --printf="%Y" "$FOLDER/$LAST_MODIFIED_FILE")))
   LAST_MODIFIED_DATE=`sudo -u mysql stat "$FOLDER/$LAST_MODIFIED_FILE" | grep Modify | awk -F "[ .]" '{print $2,$3}'`

   D=$(($DIFF/3600/24)); DIFF=$(($DIFF-$D*3600*24))
   H=$(($DIFF/3600)); DIFF=$(($DIFF-$H*3600))
   M=$(($DIFF/60)); S=$(($DIFF-$M*60))
   DIFF=""
   test $D -gt 0 && DIFF="$DIFF ${D}d"
   test $H -gt 0 && DIFF="$DIFF ${H}h"
   test $M -gt 0 && DIFF="$DIFF ${M}m"
   test $S -gt 0 && DIFF="$DIFF ${S}s"
   printf "%-40s %25s %20s\n" "$2$LAST_MODIFIED_FILE" "$LAST_MODIFIED_DATE" "$DIFF"
}


function last_modifications(){
   echo -e "\n"
   get_last_modified_file "$LOGDIR" "" ib_logfile
   while read DATABASE; do
      get_last_modified_file "$DATADIR/$DATABASE/" "$DATABASE/"
   done < <(mysql -BN -e 'show databases' | grep -v schema )
}



function federated(){
   printf "$HEADER" "federated:" $(mysql -BN -e "select ifnull(group_concat(concat(host, ': ', db) SEPARATOR '; '), '<no>') from mysql.servers")
}


# ----------------------------------------------------------------------------------------------------------
DATADIR=$(mysql -BN -e 'select @@datadir')
LOGDIR=$(mysql -BN -e 'select @@innodb_log_group_home_dir')
test "$LOGDIR" == "./" && LOGDIR=$DATADIR



is_running
echo

if [ $? -eq 0 ]; then
   master_status
   slave_status
   echo 
   show_databases
   echo
   federated
   echo
   processlist_status

   last_modifications
fi


exit 0