#!/bin/sh
CLASS=$1

if [ $CLASS = "yarn" ]; then
    GREP="NodeManager\|ResourceManager"
fi
if [ $CLASS = "resourcemanager" ]; then
    GREP="ResourceManager"
fi
if [ $CLASS = "nodemanager" ]; then
    GREP="Nodemanager"
fi
if [ $CLASS = "hdfs" ]; then
    GREP="DataNode\|NameNode"
fi
if [ $CLASS = "zookeeper" ]; then
    GREP="QuorumPeerMain"
fi
if [ -z $CLASS ]; then
    echo "killing HDFS, YARN, and ZK."
    GREP="DataNode\|NameNode\|NodeManager\|ResourceManager\|QuorumPeerMain"
fi

if [ ! -z $GREP ]; then
    APACHE_PIDS=`jps | grep $GREP | awk '{print $1}'`
fi

while [ -n "$APACHE_PIDS" ]; do

    echo "killing apache java processes.."
    for PID in $APACHE_PIDS
    do
	#TODO: works for hadoop daemons, but not zookeeper, since last arg of zookeeper command line is 
	#configuration file not class name.
	ROLE=`jps | grep "$GREP" | grep $PID | awk '{print $2}'`
	echo "killing apache java process: $PID ($ROLE)"
	kill $PID
    done

    echo "Giving pids: $APACHE_PIDS time to die.."
    sleep 10

    #terminate any stragglers
    APACHE_PIDS=`jps | grep "$GREP" | awk '{print $1}'`
    for PID in $APACHE_PIDS
    do
	echo "terminating straggler apache java process: $PID"
	kill -9 $PID
    done

    sleep 3
    APACHE_PIDS=`jps | grep "$GREP" | awk '{print $1}'`
done
