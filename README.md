# etcd-performance-isssues-experiment-framework
Experiment framework used for "Impact of etcd deployment on Kubernetes, Istio, and application performance"

## Prerequisites

This should run on what you consider to be your control node: the one that initiates and coordinates all experiments.

 1. Ensure that `timeout` is installed on your machine.
 1. Clone the git repo of the [application](https://github.com/llarsson/etcd-performance-issues-application) somewhere and point the symlink `application` to it.
 1. [Download JMeter 5.3](https://jmeter.apache.org/download_jmeter.cgi) and point the `jmeter` symlink to it.
 1. Make a RAM-disk and mount it at `/mnt/ramdisk` so that JMeter can store its data there. Obviously, it needs to be writable by the user that executes JMester (your own, probably).
 1. [Download Istio 1.1.5](https://github.com/istio/istio/releases/tag/1.1.5) (later may possibly work, too) and point the `istio` symlink to it.
 1. Get PostgreSQL up and running on your machine. Create a database called `experiments` (default, you can use your own name and set the `DBNAME` environment variable if you wish) and make sure your user has permissions in it.
 1. Run `./reset-database.sh` to reset the database to an empty state (or, if you already have things in it, just make sure that `database-migrations/version0.sql` has been run, and then the others in there in succession).
 1. Set up a cluster of JMeter nodes, define their IP addresses in `jmeter/bin/jmeter.properties` under the `remote_hosts` key as per JMeter documentation. Place a SystemD Service unit file called `jmeter-server.service` such that it can be found and used. Depending on where and how you installed JMeter, inspiration can be found [over here](https://gist.github.com/sloppycoder/a8aea05f3877997b31686a9deaa75ba6).

## Usage

This framework does not (yet?) have great user experience. You have been warned. :) Please direct any questions about usage to [mailto:larsson@cs.umu.se](Lars Larsson).

Take inspiration from the shell scripts that define experiments, such as `define-loadgeneration.sh` in how to define scenarios and experiments. If you need to add columns to the database, make a database migration for it. Give all your scenarios some common prefix. 

Run your experiments (in a `tmux` session if you value your sanity!) via the `./perform-experiments.sh` file, passing in the prefix you used for the scenarios as a parameter. It will be used by a rather complicated SQL query to find and prioritize among the experiments that need to run.

Some inspiration for SQL queries are in the `sql/` directory. You may or may not find them useful.
