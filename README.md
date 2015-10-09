# mysql-scripts
short bash, python scripts


##### replica_behind_master.sh <$interval_in_seconds>
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
