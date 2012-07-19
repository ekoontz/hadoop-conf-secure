#!/bin/sh

kill `ps -ef | grep java | grep apache | awk '{print $2}'`
sleep 10
kill -9 `ps -ef | grep java | grep apache | awk '{print $2}'`

cd $HOME/hadoop-runtime
rm -rf /tmp/hadoop-$USER
bin/hdfs namenode -format
bin/hdfs namenode &
bin/hdfs datanode &
bin/yarn resourcemanager &
bin/yarn nodemanager &
cd $HOME/zookeeper
bin/zkServer.sh start-foreground 

