#!/bin/bash


#
# Script used to minotor slave's lags behind master
#
# Sample calls:
# ./replica_behind_master.sh
# ./replica_behind_master.sh 10
#

COLOR_GREEN=$(tput setaf 2)
COLOR_RED=$(tput setaf 1)
COLOR_NO=$(tput sgr0)

ROWS_PER_SCREEN=30


SLEEP=$1

test -z "$SLEEP" && SLEEP=5


# ----------------------------------------------------------------------------------------------
# ----------------------------------------- OUTPUT ---------------------------------------------
# ----------------------------------------------------------------------------------------------
function print_header(){
    printf "\n %5s %5s | %12s | %7s %9s | %9s | %s\n\n" IO SQL lag sps sps_avg rfile_cnt eta
}


function print_error(){
    IO=$(printf "%5s" $1)
    [[ "$1" == "No" ]] && IO="${COLOR_RED}${IO}${COLOR_NO}"

    SQL=$(printf "%5s" $2)
    [[ "$2" == "No" ]] && SQL="${COLOR_RED}${SQL}${COLOR_NO}"

    echo -e " $IO $SQL | ${COLOR_RED}$3${COLOR_NO}"
}


function print_row(){
    local IO=$(printf "%5s" $1)
    [[ "$1" == "No" ]] && IO="${COLOR_RED}${IO}${COLOR_NO}"
    local SQL=$(printf "%5s" $2)
    local LAG=$(printf "%12s" $(int_to_datetime $3))
    local SPS=$(printf "%7s" $4)

    local ETA="-"
    if [ "$(echo $SPS'>'0 | bc -l)" -eq 1 ]; then
        SPS="${COLOR_GREEN}$SPS${COLOR_NO}"
    elif [ "$(echo $SPS'<'0 | bc -l)" -eq 1 ]; then
        SPS="${COLOR_RED}$SPS${COLOR_NO}"
    fi

    local SPS_AVG=$(printf "%9s" $5)
    if [ "$(echo $SPS_AVG'>'0 | bc -l)" -eq 1 ]; then
        ETA=$(int_to_datetime $(python -c "print int($3/$5)"))
        SPS_AVG="${COLOR_GREEN}$SPS_AVG${COLOR_NO}"
    elif [ "$(echo $SPS_AVG'<'0 | bc -l)" -eq 1 ]; then
        SPS_AVG="${COLOR_RED}$SPS_AVG${COLOR_NO}"
    fi

    local RFILE_CNT=$(printf "%9s" $6)

    echo -e " $IO $SQL | $LAG | $SPS $SPS_AVG | $RFILE_CNT | $ETA"
}


# ----------------------------------------------------------------------------------------------
# --------------------------------------- CONVERTS ---------------------------------------------
# ----------------------------------------------------------------------------------------------
function int_to_datetime(){
    local LAG="$1"

    local DAYS=$(($LAG / 24 / 3600)); LAG=$(($LAG - 24 * 3600 * $DAYS))
    local HOURS=$(($LAG/3600)); LAG=$(($LAG - 3600 * $HOURS))
    local MINUTES=$(($LAG/60))
    local SECONDS=$(($LAG - 60 * $MINUTES))

    local RESULT=
    [[ "$DAYS" -gt 0 ]] && RESULT="${DAYS}d"
    [[ "$HOURS" -gt 0 ]] && RESULT="$RESULT${HOURS}h"
    [[ "$MINUTES" -gt 0 ]] && RESULT="$RESULT${MINUTES}m"
    RESULT="$RESULT${SECONDS}s"

    echo $RESULT
}


# ----------------------------------------------------------------------------------------------
# ------------------------------------------- MISC ---------------------------------------------
# ----------------------------------------------------------------------------------------------
function extract_value(){
    echo "$1" | grep -w "$2" | cut -d ':' -f 2- | sed 's/^ //g'
}


# ----------------------------------------------------------------------------------------------
# ------------------------------------------- MAIN ---------------------------------------------
# ----------------------------------------------------------------------------------------------
STATUS="$(mysql -e 'show slave status\G' 2>/dev/null)"
if [ -z "$STATUS" ]; then
    echo "Not a replica"
    exit 1
fi

START_LAG=$(echo "$STATUS" | grep -w Seconds_Behind_Master  | cut -d ':' -f 2- | sed 's/^ //g' )
PREV_LAG=$START_LAG
ITERATIONS=1

DATADIR=$(mysql -BN -e 'select @@datadir')
RELAY_LOG_FILE=$(mysql -BN -e 'show variables' | grep -w relay_log | awk '{print $2}' | sed 's/ //g')
[ -z "$RELAY_LOG_FILE" ] && RELAY_LOG_FILE="relay-bin."

echo "going to sleep for ${SLEEP}s"
print_header

while :; do
    STATUS="$(mysql -e 'show slave status\G')"
    if [ $? -eq 0 ]; then
        CURRENT_LAG=$(extract_value "$STATUS" Seconds_Behind_Master)
        IO_THREAD=$(extract_value "$STATUS" Slave_IO_Running)
        SQL_THREAD=$(extract_value "$STATUS" Slave_SQL_Running)
        LAST_ERROR=$(extract_value "$STATUS" Last_Error)
    else
        printf "${COLOR_RED}Cannot connect to MySQL${COLOR_NO}"
        ITERATIONS=$((ITERATIONS+1))
        continue
    fi

    if [[ "$CURRENT_LAG" == "NULL" ]]; then
        test -z "$LAST_ERROR" && LAST_ERROR="Some threads are not running. Please check"

        print_error $IO_THREAD $SQL_THREAD  "$LAST_ERROR"
    else
        SPS=$(python -c "print('%0.2f' % (($PREV_LAG-$CURRENT_LAG)/$SLEEP.))")
        SPS_AVG=$(python -c "print('%0.3f' % (($START_LAG-$CURRENT_LAG)/$ITERATIONS./$SLEEP))")
        [ ! -z "$RELAY_LOG_FILE" ] && RELAY_LOG_FILE_CNT=$(sudo -u mysql ls $DATADIR | grep $RELAY_LOG_FILE | grep -v index | wc -w)

        print_row $IO_THREAD $SQL_THREAD $CURRENT_LAG "$SPS" $SPS_AVG $RELAY_LOG_FILE_CNT

        PREV_LAG=$CURRENT_LAG
    fi

    ITERATIONS=$((ITERATIONS+1))
    [[ $(($ITERATIONS % ROWS_PER_SCREEN)) -eq 0 ]] && print_header

    sleep $SLEEP
done
