#!/bin/sh

#TODO: just use jps rather than all of this messing with ps.
APACHE_PIDS=`jps | grep "DataNode\|NameNode\|QuorumPeerMain\|NodeManager\|ResourceManager" | awk '{print $1}'`
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
