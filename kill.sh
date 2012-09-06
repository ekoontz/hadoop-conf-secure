#!/bin/sh

CLASS=$1

if [ $1 = "yarn" ]; then
    APACHE_PIDS=`jps | grep "NodeManager\|ResourceManager" | awk '{print $1}'`
else
    if [ $1 = "hdfs" ]; then
	APACHE_PIDS=`jps | grep "DataNode\|NameNode" | awk '{print $1}'`
    else
	if [ $1 = "zookeeper" ]; then
	    APACHE_PIDS=`jps | grep "QuorumPeerMain" | awk '{print $1}'`
	else
	    if [ -z $1 ]; then
		echo "killing HDFS, YARN, and ZK."
		APACHE_PIDS=`jps | grep "DataNode\|NameNode\|NodeManager\|ResourceManager\|QuorumPeerMain" | awk '{print $1}'`
	    else
		echo "Unknown class '$1' of Java pids to kill."
		echo "Usage: kill.sh (yarn|hdfs|zookeeper)"
		exit 1
	    fi
	fi
    fi
fi

while [ -n "$APACHE_PIDS" ]; do

    echo "killing apache java processes.."
    for PID in $APACHE_PIDS
    do
	#TODO: works for hadoop daemons, but not zookeeper, since last arg of zookeeper command line is 
	#configuration file not class name.
	ROLE=`jps | grep "DataNode\|NameNode\|QuorumPeerMain\|NodeManager\|ResourceManager" | grep $PID | awk '{print $2}'`
	echo "killing apache java process: $PID ($ROLE)"
	kill $PID
    done

    echo "Giving pids: $APACHE_PIDS time to die.."
    sleep 10

    #terminate any stragglers
    APACHE_PIDS=`jps | grep "DataNode\|NameNode\|QuorumPeerMain\|NodeManager\|ResourceManager" | awk '{print $1}'`
    for PID in $APACHE_PIDS
    do
	echo "terminating straggler apache java process: $PID"
	kill -9 $PID
    done

    sleep 3
    APACHE_PIDS=`jps | grep "DataNode\|NameNode\|QuorumPeerMain\|NodeManager\|ResourceManager" | awk '{print $1}'`
done
