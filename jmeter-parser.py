#!/usr/bin/env python3

import numpy as np
import csv
from collections import defaultdict
import psycopg2
import sys
import os

successes = defaultdict(list)
failures = defaultdict(list)
total = defaultdict(list)
connect_times = defaultdict(list)
threadcount = {}

errors = set()

with open(sys.argv[1], "r") as csvfile:
    results = csv.DictReader(csvfile)
    for row in results:
        second = int(row['timeStamp']) - (int(row['timeStamp']) % 1000)
        processing_time = int(row['Latency']) - int(row['Connect'])
        connect_times[second].append(int(row['Connect']))
        if row['success'] == "true":
            successes[second].append(processing_time)
            total[second].append(processing_time)
        else:
            if processing_time < 0:
                # Connection timeout! Report as 'elapsed'
                failures[second].append(int(row['elapsed']))
                total[second].append(int(row['elapsed']))
            else:
                # Actual failure! Report as processing_time
                failures[second].append(processing_time)
                total[second].append(processing_time)
            errors.add(row['responseMessage'])
        if second in threadcount:
            threadcount[second] = min(threadcount[second], int(row['allThreads']))
        else:
            threadcount[second] = int(row['allThreads'])

start_time = min(total.keys())

experiment_id = os.getenv('EXPERIMENT_ID')
user = os.getenv('USER')
dbname = os.getenv('DBNAME', 'experiments')

connection = psycopg2.connect("dbname={} user={}".format(dbname, user))
cursor = connection.cursor()

ts_query = """INSERT INTO timeseries 
(
  experiment_id,
  timestamp,
  success_rps,
  success_avg,
  success_median,
  success_min,
  success_max,
  failure_rps,
  failure_avg,
  failure_median,
  failure_min,
  failure_max,
  total_rps,
  total_avg,
  total_median,
  total_min,
  total_max,
  connect_time_avg,
  connect_time_median,
  connect_time_min,
  connect_time_max,
  threadcount
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"""

for timestamp in total.keys():
    success_rps = None
    success_avg = None
    success_median = None
    success_min = None
    success_max = None

    failure_rps = None
    failure_avg = None
    failure_median = None
    failure_min = None
    failure_max = None

    total_rps = len(total[timestamp])
    total_avg = float(np.average(total[timestamp]))
    total_median = float(np.median(total[timestamp]))
    total_min = float(np.min(total[timestamp]))
    total_max = float(np.max(total[timestamp]))

    connect_time_avg = float(np.average(connect_times[timestamp]))
    connect_time_median = float(np.median(connect_times[timestamp]))
    connect_time_min = float(np.min(connect_times[timestamp]))
    connect_time_max = float(np.max(connect_times[timestamp]))

    if len(successes[timestamp]):
        success_rps = len(successes[timestamp])
        success_avg = float(np.average(successes[timestamp]))
        success_median = float(np.median(successes[timestamp]))
        success_min = float(np.min(successes[timestamp]))
        success_max = float(np.max(successes[timestamp]))

    if len(failures[timestamp]):
        failure_rps = len(failures[timestamp])
        failure_avg = float(np.average(failures[timestamp]))
        failure_median = float(np.median(failures[timestamp]))
        failure_min = float(np.min(failures[timestamp]))
        failure_max = float(np.max(failures[timestamp]))

    values = (
            experiment_id,
            timestamp - start_time,
            success_rps,
            success_avg,
            success_median,
            success_min,
            success_max,
            failure_rps,
            failure_avg,
            failure_median,
            failure_min,
            failure_max,
            total_rps,
            total_avg,
            total_median,
            total_min,
            total_max,
            connect_time_avg,
            connect_time_median,
            connect_time_min,
            connect_time_max,
            threadcount[timestamp]
            )
    
    cursor.execute(ts_query, values)

connection.commit()

stats_query = """INSERT INTO statistics (
  experiment_id,
  success_reqs,
  success_min,
  success_avg,
  success_median,
  success_max,
  success_percentile_50,
  success_percentile_75,
  success_percentile_90,
  success_percentile_95,
  success_percentile_99,
  failure_reqs,
  failure_min,
  failure_avg,
  failure_median,
  failure_max,
  failure_percentile_50,
  failure_percentile_75,
  failure_percentile_90,
  failure_percentile_95,
  failure_percentile_99,
  total_reqs,
  total_min,
  total_avg,
  total_median,
  total_max,
  total_percentile_50,
  total_percentile_75,
  total_percentile_90,
  total_percentile_95,
  total_percentile_99,
  connect_time_min,
  connect_time_avg,
  connect_time_median,
  connect_time_max,
  connect_time_percentile_50,
  connect_time_percentile_75,
  connect_time_percentile_90,
  connect_time_percentile_95,
  connect_time_percentile_99
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""

success_entries = [item for sublist in successes.values() for item in sublist]
failure_entries = [item for sublist in failures.values() for item in sublist]
total_entries = [item for sublist in total.values() for item in sublist]
connect_time_entries = [item for sublist in connect_times.values() for item in sublist]

success_reqs = None
success_min = None
success_avg = None
success_median = None
success_max = None
success_percentile_50 = None
success_percentile_75 = None
success_percentile_90 = None
success_percentile_95 = None
success_percentile_99 = None
failure_reqs = None
failure_min = None
failure_avg = None
failure_median = None
failure_max = None
failure_percentile_50 = None
failure_percentile_75 = None
failure_percentile_90 = None
failure_percentile_95 = None
failure_percentile_99 = None

if len(success_entries):
    success_reqs = len(success_entries)
    success_min = float(np.min(success_entries)),
    success_avg = float(np.average(success_entries)),
    success_median = float(np.median(success_entries)),
    success_max = float(np.max(success_entries)),
    success_percentile_50 = float(np.percentile(success_entries, 50)),
    success_percentile_75 = float(np.percentile(success_entries, 75)),
    success_percentile_90 = float(np.percentile(success_entries, 90)),
    success_percentile_95 = float(np.percentile(success_entries, 95)),
    success_percentile_99 = float(np.percentile(success_entries, 99)),

if len(failure_entries):
    failure_reqs = len(failure_entries)
    failure_min = float(np.min(failure_entries))
    failure_avg = float(np.average(failure_entries))
    failure_median = float(np.median(failure_entries))
    failure_max = float(np.max(failure_entries))
    failure_percentile_50 = float(np.percentile(failure_entries, 50))
    failure_percentile_75 = float(np.percentile(failure_entries, 75))
    failure_percentile_90 = float(np.percentile(failure_entries, 90))
    failure_percentile_95 = float(np.percentile(failure_entries, 95))
    failure_percentile_99 = float(np.percentile(failure_entries, 99))

values = (
        experiment_id,
        success_reqs,
        success_min,
        success_avg,
        success_median,
        success_max,
        success_percentile_50,
        success_percentile_75,
        success_percentile_90,
        success_percentile_95,
        success_percentile_99,
        failure_reqs,
        failure_min,
        failure_avg,
        failure_median,
        failure_max,
        failure_percentile_50,
        failure_percentile_75,
        failure_percentile_90,
        failure_percentile_95,
        failure_percentile_99,
        len(total_entries),
        float(np.min(total_entries)),
        float(np.average(total_entries)),
        float(np.median(total_entries)),
        float(np.max(total_entries)),
        float(np.percentile(total_entries, 50)),
        float(np.percentile(total_entries, 75)),
        float(np.percentile(total_entries, 90)),
        float(np.percentile(total_entries, 95)),
        float(np.percentile(total_entries, 99)),
        float(np.min(connect_time_entries)),
        float(np.average(connect_time_entries)),
        float(np.median(connect_time_entries)),
        float(np.max(connect_time_entries)),
        float(np.percentile(connect_time_entries, 50)),
        float(np.percentile(connect_time_entries, 75)),
        float(np.percentile(connect_time_entries, 90)),
        float(np.percentile(connect_time_entries, 95)),
        float(np.percentile(connect_time_entries, 99)),
        )

cursor.execute(stats_query, values)
connection.commit()

cursor.close()
connection.close()

print("Done storing JMeter output for experiment {}".format(experiment_id))

