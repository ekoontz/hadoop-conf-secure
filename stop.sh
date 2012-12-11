#!/bin/sh
#PS="jps"
#AWK="awk '{print \$1}'"
PS="ps -ef"

#'AWK' as a variable doesn't work yet: using hardcoded awk calls below.
AWK="awk '{print \$2}'"
echo $AWK

#TODO: also check ps, because jps doesn't necessarily find all processes..
# https://gist.github.com/4028435
#
# "If jps doesn't discover a process, it doesn't mean that the Java process can't be attached or spelunked. 
# "It just means that it isn't advertising itself as available.".
#
#  http://www.ibm.com/developerworks/java/library/j-5things8/index.html

# check input arg
if [ ! $1 ]; then
    # will kill everything (hdfs,yarn,zookeeper)
    CLASS=""
else
    CLASS=$1
fi

if [ -z $CLASS ]; then
    echo "killing HDFS, YARN, and ZK."
    GREP="DataNode\|NameNode\|NodeManager\|ResourceManager\|QuorumPeerMain\|DFSZKFailoverController\|JournalNode"
else
    if [ $CLASS = "yarn" ]; then
	GREP="NodeManager\|ResourceManager"
    fi
    if [ $CLASS = "resourcemanager" ]; then
	GREP="ResourceManager"
    fi
    if [ $CLASS = "nodemanager" ]; then
	GREP="Nodemanager"
    fi
    if [ $CLASS = "secondarynamenode" ]; then
	GREP="SecondaryNameNode"
    fi
#this rule will match the secondary name node as well as the name node (since the 2NN's name is "SecondaryNameNode")
    if [ $CLASS = "hdfs" ]; then
	GREP="DataNode\|NameNode\|DFSZKFailoverController\|JournalNode"
    fi
    if [ $CLASS = "zookeeper" ]; then
	GREP="QuorumPeerMain"
    fi
fi
if [ ! -z $GREP ]; then
    APACHE_PIDS=`$PS | grep $GREP | grep -v grep | awk '{print $2}'`
fi

while [ -n "$APACHE_PIDS" ]; do
    echo "killing apache java processes.."
    for PID in $APACHE_PIDS
    do
	#TODO: works for hadoop daemons, but not zookeeper, since last arg of zookeeper command line is 
	#configuration file not class name.
	ROLE=`$PS | grep "$GREP" | grep $PID | awk '{print $2}'`
	echo "killing apache java process: $PID ($ROLE)"
	kill $PID
    done

    echo "Giving pids: $APACHE_PIDS time to die.."
    sleep 10

    #terminate any stragglers
    APACHE_PIDS=`$PS | grep "$GREP" | grep -v grep | awk '{print $2}'`
    for PID in $APACHE_PIDS
    do
	echo "terminating straggler apache java process: $PID"
	kill -9 $PID
    done

    sleep 3
    APACHE_PIDS=`$PS | grep "$GREP" | grep -v grep | awk '{print $2}'`
done
