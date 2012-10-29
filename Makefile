.PHONY=all clean install start restart start-yarn start-hdfs start-zookeeper test test-hdfs \
  test-mapreduce stop principals printenv start-namenode start-datanode initialize-hdfs\
  envquiet login hdfsuser stop stop-hdfs stop-yarn stop-zookeeper report report2 sync \
  runtest manualsync start-resourcemanager start-nodemanager restart-hdfs test-terasort \
  test-terasort2 stop-secondarynamenode
# ^^ TODO: add test-zookeeper target and add it to .PHONY above

include hostnames.mk

# config files that are rewritten by rewrite-config.xsl.
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties hadoop-env.sh yarn-env.sh hadoop-conf.sh services.keytab

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/tmp/hadoop-data

HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper
REALM=EXAMPLE.COM
KRB5_CONFIG=./krb5.conf
DNS_SERVER=`cat hadoop-conf.sh | grep DNS_SERVERS | awk 'BEGIN {FS = "="} ; {print $$2}'`
all: $(CONFIGS)

printenv:
	make -s -e envquiet

envquiet:
	echo "Hadoop Runtime directory:     $(HADOOP_RUNTIME)"
	echo "Zookeeper Runtime directory:  $(ZOOKEEPER_HOME)"
	echo "Master hostname:              $(MASTER)"
	echo "Tmp directory:                $(TMPDIR)"
	echo "Realm name:                   $(REALM)"

services.keytab:
	scp principals.sh $(DNS_SERVER):
	ssh -t $(DNS_SERVER) "sh principals.sh $(MASTER)"
	scp $(DNS_SERVER):services.keytab .

install: all ~/hadoop-runtime services.keytab
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

~/hadoop-runtime:
	ln -s `find $(HOME)/hadoop-common/hadoop-dist/target -name "hadoop*"  -type d -maxdepth 1` $(HOME)/hadoop-runtime

stop: stop-hdfs stop-yarn stop-zookeeper
	echo
# ^^^ need a dummy action here (e.g. an echo) to avoid default action -
# default action is "cat stop.sh > stop", for some reason.)

stop-hdfs: 
	-sh stop.sh hdfs

stop-yarn:
	-sh stop.sh yarn

stop-secondary-namenode:
	-sh stop.sh secondarynamenode

stop-nodemanager:
	-sh stop.sh nodemanager

stop-zookeeper:
	-sh stop.sh zookeeper

start-hdfs: stop-hdfs initialize-hdfs start-namenode start-secondary-namenode start-datanode

initialize-hdfs:
	-rm -rf /tmp/logs
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format

start-namenode: services.keytab /tmp/hadoop-data/dfs/name
	$(HADOOP_RUNTIME)/bin/hdfs namenode &

/tmp/hadoop-data/dfs/name:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format

start-secondary-namenode: services.keytab
	$(HADOOP_RUNTIME)/bin/hdfs secondarynamenode &


start-datanode: services.keytab
	$(HADOOP_RUNTIME)/bin/hdfs datanode &

start-yarn: stop-yarn start-resourcemanager start-nodemanager

start-resourcemanager:
	$(HADOOP_RUNTIME)/bin/yarn resourcemanager &

start-nodemanager:
	$(HADOOP_RUNTIME)/bin/yarn nodemanager &

start-zookeeper:
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start

restart: stop start

restart-hdfs: stop-hdfs start-hdfs

start: sync services.keytab start-hdfs start-yarn start-zookeeper

start2: manualsync services.keytab start-hdfs start-yarn start-zookeeper

manualsync:
	ssh -t $(DNS_SERVER) "sudo date `date '+%m%d%H%M%Y.%S'`"

sync-time-of-dns-server:
	export DNS_SERVER=$(DNS_SERVER)	; make -s -e sync

# restart ntpdate and krb5kdc on server.
sync:
	ssh -t $(DNS_SERVER) "sudo service ntpdate restart"
	ssh -t $(DNS_SERVER) "sudo service krb5kdc restart"

# use password authentication.
login:
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit `whoami`@$(REALM)

# use keytab authentication.
hdfsuser: services.keytab
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit -k -t services.keytab hdfs/$(MASTER)@$(REALM)

rmr-tmp: hdfsuser
	-$(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp
	$(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp

# this modifies HDFS permissions so that normal user can run jobs.
permissions: rmr-tmp
	-$(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp
	$(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp

	-$(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/user
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/user

	-$(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp/yarn
	$(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp/yarn
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp/yarn

	$(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(MASTER):8020/

#print some diagnostics
report:
	export MASTER=$(MASTER) REALM=$(REALM) DNS_SERVER=$(DNS_SERVER) HADOOP_RUNTIME=$(HADOOP_RUNTIME); make -s -e report2

report2:
	echo " HOSTS:"
	echo "  MASTER:                          $(MASTER)"
	echo "   HOSTNAME:                        `hostname -f`"
	echo "   HADOOP_RUNTIME DIR:             $(HADOOP_RUNTIME)"
	echo " DNS:"
	echo "  DNS_SERVER:                      $(DNS_SERVER)"
	echo "  DNS CLIENT QUERIES:"
	echo "   MASTER DNS LOOKUP: $(MASTER) => `dig @$(DNS_SERVER) $(MASTER) +short`"
	export MASTER_IP=`dig @$(DNS_SERVER) $(MASTER) +short`; echo "   REVERSE MASTER DNS LOOKUP: $$MASTER_IP => `dig @$(DNS_SERVER) -x $$MASTER_IP +short`"
	echo " DATE:"
	echo "  MASTER DATE:                    " `date`
	echo "  DNS_SERVER DATE:                " `ssh $(DNS_SERVER) date`
	echo "  DEBUG DATE INFO:"
	export MASTER_IP=`dig @$(DNS_SERVER) $(MASTER) +short`; echo `ssh -t $(DNS_SERVER) "sudo ntpdate -d $$MASTER_IP"`
	echo " KERBEROS:"
	echo "  REALM:                           $(REALM)"
	echo "  TICKET CACHE:"
	echo `klist`
	echo "  KEYTAB:"
	ktutil -k services.keytab l | head
	echo "(showing above only first 10 lines of keytab contents)"
	echo ""
	echo " HADOOP CONF:"
	echo "  HDFS:"
#TODO: use hadoop's 'get properties' ability rather than xpath.
	echo "   fs.defaultFS:                    " `xpath $(HADOOP_RUNTIME)/etc/hadoop/core-site.xml "/configuration/property[name='fs.defaultFS']/value/text()" 2> /dev/null`
	echo "   dfs.namenode.keytab.file:        " `xpath $(HADOOP_RUNTIME)/etc/hadoop/hdfs-site.xml "/configuration/property[name='dfs.namenode.keytab.file']/value/text()" 2> /dev/null`
	echo "   dfs.namenode.kerberos.principal: " `xpath $(HADOOP_RUNTIME)/etc/hadoop/hdfs-site.xml "/configuration/property[name='dfs.namenode.kerberos.principal']/value/text()" 2> /dev/null`
	echo "   dfs.datanode.keytab.file:        " `xpath $(HADOOP_RUNTIME)/etc/hadoop/hdfs-site.xml "/configuration/property[name='dfs.datanode.keytab.file']/value/text()" 2> /dev/null`
	echo "   dfs.datanode.kerberos.principal: " `xpath $(HADOOP_RUNTIME)/etc/hadoop/hdfs-site.xml "/configuration/property[name='dfs.datanode.kerberos.principal']/value/text()" 2> /dev/null`
	echo "  YARN:"
	echo "   yarn.resourcemanager.keytab:     " `xpath $(HADOOP_RUNTIME)/etc/hadoop/yarn-site.xml "/configuration/property[name='yarn.resourcemanager.keytab']/value/text()" 2> /dev/null`
	echo "   yarn.resourcemanager.principal:  " `xpath $(HADOOP_RUNTIME)/etc/hadoop/yarn-site.xml "/configuration/property[name='yarn.resourcemanager.principal']/value/text()" 2> /dev/null`
	echo "   yarn.nodemanager.keytab:         " `xpath $(HADOOP_RUNTIME)/etc/hadoop/yarn-site.xml "/configuration/property[name='yarn.nodemanager.keytab']/value/text()" 2> /dev/null`
	echo "   yarn.nodemanager.principal:      " `xpath $(HADOOP_RUNTIME)/etc/hadoop/yarn-site.xml "/configuration/property[name='yarn.nodemanager.principal']/value/text()" 2> /dev/null`

test:
	export MASTER=$(MASTER); make -s -e runtest

runtest: test-hdfs test-mapreduce

test-hdfs: permissions login
	$(HADOOP_RUNTIME)/bin/hadoop fs -ls hdfs://$(MASTER):8020/

test-mapreduce: login
	-$(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/user/`whoami`/*
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar pi 5 5

test-terasort:
	-$(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/user/`whoami`/*
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar teragen 10000000 hdfs://$(MASTER):8020/user/`whoami`/teragen
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar terasort hdfs://$(MASTER):8020/user/`whoami`/teragen hdfs://$(MASTER):8020/user/`whoami`/terasort

test-terasort2:
	$(HADOOP_RUNTIME/bin/hadoop jar $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar teragen 100000 hdfs://$(MASTER):8020/user/`whoami`/teragen

#deprecated.
hdfs-test: test-hdfs
mapreduce-test: test-mapreduce

clean:
	-rm $(CONFIGS) services.keytab

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` \
                 --stringparam dns_server $(DNS_SERVER) \
                 rewrite-config.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` \
                 --stringparam dns_server $(DNS_SERVER) \
	         --stringparam homedir `echo $$HOME` \
	         --stringparam realm $(REALM) \
                 --stringparam tmpdir $(TMPDIR) rewrite-config.xsl $^  | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` \
                 --stringparam dns_server $(DNS_SERVER) \
	         --stringparam homedir `echo $$HOME` rewrite-config.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` \
                 --stringparam dns_server $(DNS_SERVER) \
	         --stringparam realm $(REALM) \
	         --stringparam homedir `echo $$HOME` rewrite-config.xsl $^ | xmllint --format - > $@

