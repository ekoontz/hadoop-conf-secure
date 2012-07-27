#!/bin/sh

#TODO: just use jps rather than all of this messing with ps.
APACHE_STUFF=`ps -ef --cols 1000 | grep java | grep "zookeeper\|hadoop" | awk '{print $2}'`
while [ -n "$APACHE_STUFF" ]; do

    echo "killing apache java processes.."
    for PID in $APACHE_STUFF
    do
	#TODO: works for hadoop daemons, but not zookeeper, since last arg of zookeeper command line is 
	#configuration file not class name.
	ROLE=`ps -e -o pid,cmd --cols 3000 | grep "^\s*$PID" | awk '{print $NF}'  `
	echo "killing apache java process: $PID ($ROLE)"
	kill $PID
    done

    sleep 10

    #terminate any stragglers
    APACHE_STUFF=`ps -ef --cols 1000 | grep java | grep "zookeeper\|hadoop" | awk '{print $2}'`
    for PID in $APACHE_STUFF
    do
	echo "terminating apache java process: $PID"
	kill -9 $PID
    done

    sleep 3
    APACHE_STUFF=`ps -ef --cols 1000 | grep java | grep "zookeeper\|hadoop" | awk '{print $2}'`
done
