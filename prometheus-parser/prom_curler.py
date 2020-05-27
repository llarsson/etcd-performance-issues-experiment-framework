#!/usr/bin/env python3

import requests
import json
import os
import sys
import time, datetime
import argparse
import psycopg2
import urllib.parse as urlparser
from dateutil import parser as timeparser

SERVERS = {'PROMETHEUS-OPERATOR': 'localhost:9090', 'PROMETHEUS-ISTIO': 'localhost:9091'}

def main(args):
    import json

    connection = None
    try:
        connection = psycopg2.connect("dbname={} user={}".format(args.db_name, args.db_user))
    except Exception as e:
        print("Failed - {}".format(e))

    metrics = {}
    try:
        with open(args.targets_file) as json_file:
            metrics = json.load(json_file)
    except Exception as e:
        print("Failed - {}".format(e))


    ''' Scrape targets '''
    for name, info in metrics.items():
        data = {}
        try:
            request = "http://{}/api/v1/query_range".format(SERVERS[info['SERVER']])
            params = {
                    'query': info['QUERY'],
                    'start': timeparser.parse(args.start_time).strftime("%s"),
                    'end': timeparser.parse(args.end_time).strftime("%s"),
                    'step': info['STEP'],
                    'timeout': "180s"
                    }
            response = requests.get(request, params)
            data = response.json()

        except Exception as e:
            print('Failed to scrape - {}'.format(str(e)))
            if info['SERVER'] == 'PROMETHEUS-OPERATOR':
                print('FATAL error since it was the Prometheus Operator service')
                sys.exit(1)
            else:
                print('WARNING since server was the Istio Prometheus server')
                continue

        try:
            store_batch(connection, args.exp_id, name, info.get('NAMING_KEY', None), data)
        except Exception as e:
            print("Failed to store batch {} - {}".format(info.get('NAMING_KEY', None), str(e)))
            sys.exit(1)

def store_batch(connection, exp_id, name, naming_key, data):
    # {'status': 'success', 'data': {'resultType': 'matrix', 'result': [{'metric': {'container_name': 'backend'}, 'values': [[1557745800, '0.0005657172014315459'], [1557745801, '0.0005657172014315459'], [1557745802, '0.0005657172014315459']]}, {'metric': {'container_name': 'istio-proxy'}, 'values': [[1557745800, '0.001037145002407858'], [1557745801, '0.001037145002407858'], [1557745802, '0.001037145002407858']]}]}}}

    cursor = connection.cursor()

    results = data['data']['result']

    experiment_start = int(timeparser.parse(args.start_time).strftime("%s"))

    for result in results:
        metric = result['metric']
        values = result['values']

        query = ""

        if naming_key:
            query = "INSERT INTO {} (experiment_id, timestamp, value, {}) VALUES (%s, %s, %s, %s)".format(name, naming_key)
            for entry in values:
                timestamp = entry[0] - experiment_start
                value = entry[1]
                cursor.execute(query, (exp_id, timestamp * 1000, value, metric[naming_key]))
        else:
            query = "INSERT INTO {} (experiment_id, timestamp, value)  VALUES (%s, %s, %s)".format(name)
            for entry in values:
                timestamp = entry[0] - experiment_start
                value = entry[1]
                cursor.execute(query, (exp_id, timestamp * 1000, value))

    connection.commit()
    cursor.close()

#    for root in data['data']['result']:
#        print (root)


#    cursor = connection.cursor()
#    query = """INSERT INTO performance
#    (experiment_id, timestamp, name, response_time, success)
#    VALUES
#    (%s, %s, %s, %s, %s)"""
#
#    for request_response in data:
#        cursor.execute(query, (self.experiment_id,
#            request_response.timestamp, request_response.name,
#            request_response.response_time, request_response.success))
#
#    connection.commit()
#    cursor.close()

if __name__ == '__main__':
    now = datetime.datetime.today()

    parser = argparse.ArgumentParser(description = 'Say hello')
    parser.add_argument('-t', '--targets_file', help="Path to JSON file with targets", default=os.path.abspath('targets.json'))
    parser.add_argument('-s', '--start_time', help="Start time", default=now - datetime.timedelta(seconds=60))
    parser.add_argument('-e', '--end_time', help="End time", default=now)
    parser.add_argument('-d', '--db_name', help="Database name", default=os.getenv('DBNAME', 'experiments'))
    parser.add_argument('-u', '--db_user', help="Database user", default=os.getenv('USER'))
    parser.add_argument('-i', '--exp_id', help="Experiment ID", default=os.getenv('EXPERIMENT_ID'))

    args = parser.parse_args()

    main(args)
