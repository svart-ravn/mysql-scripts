#!/bin/bash

TIME=30
TMP_FOLDER="/tmp"
SUDO_USER="mysql"
TMP_GENLOG_FILE="${TMP_FOLDER}/mysql_genlog.tmp.log"
OUTPUT_FILE="${TMP_FOLDER}/mysql_genlog.output"
PT_QD="pt-query-digest"
LESS_OUTPUT="y"

GENERAL_LOG_FILE_DEFAULT=

# -------------------------------------------------------
function usage() {
  cat << __USAGE__ >&2

Usage: ${0} 

Options:
   
   --time|-t) time to run
   --sudo-user|-s) user under mysql operates. Used to remove temporary general log file 
   --no-less|-n) do not less the resulting file

   --help|h)   usage

__USAGE__
} 


function get_long_options(){
   local OPTIONS=$@
   local ARGUMENTS=($OPTIONS)
   local index=0

   for ARG in $OPTIONS; do
       index=$(($index+1));
       case $ARG in
         --time|-t) TIME="${ARGUMENTS[index]}";;
         --sudo-user|-s) SUDO_USER="${ARGUMENTS[index]}";;
         --no-less|-n) LESS="";;
         --help|-h) usage; exit 1;;
      esac
   done
}


function init(){
   GENERAL_LOG_FILE_DEFAULT="$(mysql -BN -e 'select @@general_log_file')"
}


function echo_info(){
   echo ""
   echo "time:            $TIME"
   echo "sudo user:       $SUDO_USER"
   echo "tmp folder:      $TMP_FOLDER"
   echo "tmp general log: $TMP_GENLOG_FILE"
   echo "output file:     $OUTPUT_FILE"
   echo "less it?:        $LESS_OUTPUT"
   echo ""   
}


function on_exit(){
   mysql -e "set global general_log_file = '$GENERAL_LOG_FILE_DEFAULT'"
}


# ---------------------- MAIN --------------------------
get_long_options $@

init


echo_info

read -p "Would you like to continue? (yY/N): " ANSWER
if [ ! "$ANSWER" == "y" ] && [ ! "$ANSWER" == "Y" ]; then
   echo -e "exiting...\n"
   exit 1
fi


trap on_exit EXIT

mysql -e "set global general_log_file = '$TMP_GENLOG_FILE'; 
          set global general_log = 1; 
          select sleep($TIME); 
          set global general_log = 0"

$PT_QD --type genlog --limit 50 "$TMP_GENLOG_FILE" > "$OUTPUT_FILE"
if [[ $? -eq 0 && ! -z "$SUDO_USER" ]]; then
   sudo -u $SUDO_USER rm $TMP_GENLOG_FILE
fi

test ! -z "$LESS_OUTPUT" && less $OUTPUT_FILE

exit 0
