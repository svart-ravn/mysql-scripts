#!/bin/bash

# ./test.sh "2015-12-02 10:00:00" "2015-12-02 10:10:00"
START_DTM=
END_DTM=
INTERVAL=
SHIFT=0

START=
END=


# ./test.sh --action parse --range 65 --output /tmp/output_data
# ./test.sh --action view --start="2015-11-30 12:11:09" --interval 3 --output /tmp/output_data
RANGE=
FILE=

# parse, view
ACTION=parse
ACTION_KEY=


FILTER=
OUTPUT_FOLDER=/tmp/output_data
THREADS=5
DATA=


LOG_BIN_INDEX=


FILES=


# -------------------------------------------------------------------------------------------------------------------
function init(){
   START=$(date +%s -d "$START_DTM")
   END=$(date +%s -d "'$END_DTM'")
   LOG_BIN_INDEX=$(mysql -e 'show variables' | grep -w log_bin_index | awk '{print $2}' | sed 's/index$//')
   SHIFT=$(human_time_to_seconds $SHIFT)
   test -z "$SHIFT" && SHIFT=0
}


function info(){
   echo "output: $OUTPUT_FOLDER"
   echo "action: $ACTION"
   echo " range: $RANGE"
   echo " start: $START_DTM ($START) - $END_DTM ($END)"
   echo " inter: $INTERVAL"
   echo " actKEY: $ACTION_KEY"
   echo " shift: $SHIFT"
   echo " filter: $FILTER"
}


function usage(){
   echo "usage"
}


function get_long_options(){
   local ARGUMENTS=("$@")
   local index=0

   for ARG in "$@"; do
      index=$(($index+1));
      case $ARG in
         --action|-a) ACTION="${ARGUMENTS[index]}";;
         --start|-s) START_DTM="${ARGUMENTS[index]}";;
         --end|-e) END_DTM="${ARGUMENTS[index]}";;
         --range|-r) RANGE="${ARGUMENTS[index]}";;
         --output|-o) OUTPUT_FOLDER="${ARGUMENTS[index]}";;
         --file|-f) FILE="${ARGUMENTS[index]}";;
         --threads|-t) THREADS="${ARGUMENTS[index]}";;

         --filter|-f) FILTER="${ARGUMENTS[index]}";;

         --interval|-i) INTERVAL="${ARGUMENTS[index]}";;
         --shift|-s) SHIFT="${ARGUMENTS[index]}";;

         --help|-h) usage; exit 1;;
      esac
   done
}


# -----------------------------------------------------------------------------------------
function log(){
   echo "log:: $@"
}


function human_time_to_seconds(){
   PARAM="$(echo "$1" | sed 's/ //g')"
   VAL=$(echo "$PARAM" | grep -Eo '[0-9]{1,}')
   test "$(echo $PARAM | sed 's/s//')" != "$PARAM" && VAL=$VAL
   test "$(echo $PARAM | sed 's/m//')" != "$PARAM" && VAL=$(($VAL*60))
   test "$(echo $PARAM | sed 's/h//')" != "$PARAM" && VAL=$(($VAL*3600))
   test "$(echo $PARAM | sed 's/d//')" != "$PARAM" && VAL=$(($VAL*3600*24))
   test "$(echo $PARAM | sed 's/w//')" != "$PARAM" && VAL=$(($VAL*3600*24*7))
   echo $VAL
}


# -----------------------------------------------------------------------------------------
function extract_binlogs_by_date(){
   PREV=
   # including and before and one after binlog file
   for F in $(ls $LOG_BIN_INDEX*); do
      LAST_MOD=$(stat --format="%Z" "$F")
      if [ $LAST_MOD -ge $START ] && [ $LAST_MOD -le $END ]; then
         test -z "$FILES" && FILES="$FILES $PREV"
         FILES="$FILES $F"
      elif [ $LAST_MOD -gt $END ]; then
         FILES="$FILES $F"
         break
      elif [ $LAST_MOD -lt $START ]; then
         PREV=$F
      fi
   done
}


function is_number() {
   # echo "checking... $1"
   re='^[0-9]+$'
   if ! [[ $1 =~ $re ]] ; then
      return 1
   fi
   return 0
}


function extract_binlogs_by_range(){
   local FROM=$(echo $RANGE | cut -d- -f1 | sed 's/^[0]*//g')
   local TO=$(echo $RANGE | cut -d- -f2 | sed 's/^[0]*//g')
   test -z "$TO" && TO=$FROM

   for F in $(ls $LOG_BIN_INDEX*); do
      ID=$(echo "$F" | awk -F "." '{print $NF}' | sed 's/^[0]*//g')
      $(is_number $ID) || continue
      if [ $ID -ge $FROM ] && [ $ID -le $TO ]; then
         FILES="$FILES $F"
      elif [ $ID -gt $TO ]; then
         break
      fi
   done
}


function extract_binlogs_by_file(){
   FILES="$FILE"
}


# ---------------------------------------------------------------------------
function filter(){
   if [ ! -z "$START" ]; then
      END=$(($START+$INTERVAL))
      #log "test"
      #log "::$START - $END, $INTERVAL :::: $(date -d @$START), $(date -d @$END) "
      cat - | awk -v start=$START -v end=$END '{command="date -d \"" $1 " " $2  "\" +%s"; command | getline val;  if (val >= start && val < end){print $3"."$4}}'
   else
      cat - | awk '{print $3"."$4}'
   fi
}


function draw(){
   DATA="$1"
#   RES=$(echo "$DATA" | awk '{sum += $1; if(length($2) > maxlen){maxlen=length($2)}}END{print sum, maxlen}')
#   SUM=$(echo $RES | cut -d ' ' -f1)
#   PAD_1COL=$(($(echo $RES | cut -d ' ' -f2)+2))
#   PAD_2COL=$(echo $SUM | wc -c)
#   echo "$DATA" | awk -v sum=$SUM -v pad1=$PAD_1COL -v pad2=$PAD_2COL '{val=sprintf("%6.2f", 100*$1/sum); col1=sprintf("%" pad1 "s", $2); col2=sprintf("%" pad2 "s", $1); print col1, " | ", col2}' | sort
   echo "$DATA" | LANG=C sort | column -t
   echo -e "\nPress =/- to add/remove additional column with interval: ${INTERVAL}s"
   info
}


function view_overall(){
   if [[ -z "$ACTION_KEY" || "$ACTION_KEY" == "=" ]]; then
      NEW_COLUMN="$(cat $OUTPUT_FOLDER/* | filter | grep "$FILTER" | LANG=C sort | uniq -c)"
      NEW_COLUMN="$(echo "$NEW_COLUMN"; echo ".... ...."; echo "$(date -d @$START +'%y%m%d_%H:%M:%S') -DTM-")"
      echo "$NEW_COLUMN" > new
      echo "$DATA" > data
      if [  $(echo "$NEW_COLUMN" | tac - | sed '1,2d' | wc -w) -ne 0 ]; then
         if [ ! -z "$DATA" ]; then
            DATA="$(join <(echo "$DATA" | sort) <(echo "$NEW_COLUMN" | awk '{print $2, $1}' | sort) -a 1 -a 2 -o auto -e 0)"
         else
            DATA="$(echo "$NEW_COLUMN" | awk '{print $2, $1}')"
         fi
      fi
   elif [[ "$ACTION_KEY" == "-" && $(echo "$DATA" | head -1 | wc -w) -gt 2 ]]; then
      DATA="$(echo "$DATA" | awk '{r=""; for(i=1; i<NF; i++){r=r " " $i}; print r}')"
   fi

   draw "$DATA"
}


# ---------------------------------------------------------------------------

get_long_options "$@"

init

info


if [ $ACTION == "parse" ]; then
   if [ ! -z "$FILE" ]; then
      extract_binlogs_by_file
   elif [ -z "RANGE" ]; then
      extract_binlogs_by_date
   else
      extract_binlogs_by_range
   fi

   mkdir -p $OUTPUT_FOLDER
   echo $FILES | tr ' ' ' \n' | xargs -P $THREADS -i bash -c "mysqlbinlog -v {} | grep -e Table_map -e STMT_END_F | awk 'NR%2{printf \$0\" \";next;}1' | awk '{gsub(\"_rows\", \"\", \$25); split(\$11, arr, \".\"); print \$1, \$2, arr[1], arr[2], tolower(\$25)}' | sed -e 's/:$//g' -e 's/[#\`]//g' > $OUTPUT_FOLDER/file.\$(echo {} | awk -F "." '{print \$NF}').raw"
fi


if [ $ACTION == "overview" ]; then
   echo "viewing..."

   while :; do 
      clear
      view_overall
      while [[ ! $KEY == "=" && ! $KEY == "-" ]]; do
         read -s -t 1 -n 1 KEY
         #echo "res="$KEY
         ACTION_KEY=$KEY
         test "$ACTION_KEY" == "=" && START=$(($START+$SHIFT+$INTERVAL))
         sleep 0.3
      done
      KEY=
      sleep 0.3
   done
fi

if [ $ACTION == "view" ]; then
   echo "not implemented"
fi


exit 0

# TODO list:
# 1. many queries per one commit
# 4. shift and interval can be 10m2s
