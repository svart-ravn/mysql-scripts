# mysql-scripts
short bash, python scripts


##### replica-behind-master.sh <$interval_in_seconds>
```
used to show how slave lags behind the master
:~$ ./replica_behind_master.sh 5
going to sleep for 5s

    IO   SQL |          lag |     sps   sps_avg | rfile_cnt | eta

   Yes   Yes |       39m12s |   28.60    24.587 |         6 | 1m35s
   Yes   Yes |       36m38s |   30.80    24.666 |         6 | 1m29s
   Yes   Yes |       34m23s |   27.00    24.695 |         6 | 1m23s
   Yes   Yes |       32m10s |   26.60    24.719 |         6 | 1m18s
   Yes   Yes |       29m42s |   29.60    24.778 |         6 | 1m11s
   Yes   Yes |       27m10s |   30.40    24.846 |         6 | 1m5s
   Yes   Yes |       24m57s |   26.60    24.867 |         6 | 1m0s
   Yes   Yes |       22m33s |   28.80    24.913 |         6 | 54s
   Yes   Yes |        20m6s |   29.40    24.965 |         6 | 48s
   Yes   Yes |       17m22s |   32.80    25.055 |         6 | 41s
   Yes   Yes |       14m52s |   30.00    25.111 |         6 | 35s
   Yes   Yes |       12m20s |   30.40    25.171 |         6 | 29s
   Yes   Yes |        10m4s |   27.20    25.193 |         3 | 23s
   Yes   Yes |        7m12s |   34.40    25.295 |         2 | 17s
   Yes   Yes |        4m42s |   30.00    25.346 |         2 | 11s
   Yes   Yes |        1m32s |   38.00    25.482 |         2 | 3s
   Yes   Yes |           0s |   18.40    25.406 |         2 | 0s
   Yes   Yes |           0s |    0.00    25.139 |         2 | 0s

```

##### split-sql-dump.awk
```
Used to split single dump file into several sql files: one file with structure per table. Plus many files with data

sample calls:

split all tables from <mysql_dump_file.sql> into several tables
> awk -v DRY_RUN=0 -v SPLIT_FOLDER="splitted_dump" -f split-sql-dump.awk mysql_dump_file.sql

split all tables from <mysql_dump_file.sql> with names starting with either "tbl" or "login" into several tables
> awk -v INCLUDE="^tbl|^login" -v SPLIT_FOLDER="splitted_dump" -f split-sql-dump.awk mysql_dump_file.sql

the same as previous except we are excluding single table
> awk -v INCLUDE="^tbl|^login" --EXCLUDE="tbl_User" -v SPLIT_FOLDER="splitted_dump" -f split-sql-dump.awk mysql_dump_file.sql

search for table "tbl_User". Split it and all after it
> awk -v STARTING_TABLE="tbl_User" -v SPLIT_FOLDER="splitted_dump" -f split-sql-dump.awk mysql_dump_file.sql

```

##### top-genlog-online.sh
```
Script used to do the following stuff:
- resets veriable 'general_log_file'
- enables gen_log
- sleeps for $TIME seconds
- disables gen_log
- parses tmp general log file using pt-query-digest
- displays the results and quit
- restore 'general_log_file' variable to default value

it's just a light wrapper over the pt-query-digest.

Requires:
- pt-query-digest been in $PATH
- you can provide --sudo-user to remove tmp general log file (mysql by default)

sample calls:

runs for 10s and removes tmp gen log file
> ./tmp-genlog-online.sh --time 10

runs for 30s and doesn't remove tmp gen log file
> ./tmp-genlog-online.sh --sudo-user "" 

```

##### data_recovery.sh
```
Used to recover data in case if ibd was corrupted

sample call:

> ./data_recovery.sh <database> <tablename>
```
