.PHONY=all clean install start restart start-yarn start-hdfs start-zookeeper test test-hdfs \
  test-mapreduce stop principals printenv start-namenode start-datanode initialize-hdfs\
  envquiet login relogin logout hdfsuser stop stop-hdfs stop-yarn stop-zookeeper report \
  report2 sync runtest manualsync start-resourcemanager start-nodemanager restart-hdfs \
  test-terasort test-terasort2 stop-secondarynamenode rm-hadoop-runtime-symlink \
  ha-install start-jn build clean-logs terms stop-on-guest touch-logs touch-logs-on-guest

# ^^ TODO: add test-zookeeper target and add it to .PHONY above

# config files that are rewritten by rewrite-config.xsl.
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml ha-hdfs-site.xml ha-core-site.xml
HA_CONFIGS=hdfs-site-ha.xml
CLUSTER=ekoontz1
MASTER=$(CLUSTER)
GUEST=centos1.local
MASTER_HOST=`hostname -f | tr  '[:upper:]' '[:lower:]'`
# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties hadoop-env.sh yarn-env.sh hadoop-conf.sh services.keytab

# TMPDIR: Should be on a filesystem big enough to do hadoop testing/dev. All
# Used for namenode and datanode storage.
TMPDIR=/tmp/hadoop-data

HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper
REALM=EXAMPLE.COM
KRB5_CONFIG=./krb5.conf
DNS_SERVER=`cat hadoop-conf.sh | grep DNS_SERVERS | awk 'BEGIN {FS = "="} ; {print $$2}'`

LOG=HADOOP_ROOT_LOGGER=INFO,console HADOOP_SECURITY_LOGGER=INFO,console

all: $(CONFIGS)

ha-config: ha-hdfs-site.xml

ha-hdfs-site.xml: templates/ha-hdfs-site.xsl hdfs-site.xml 
	DNS_SERVER_NAME=$(GUEST) \
        MASTER=$(MASTER) \
	xsltproc --stringparam cluster 'ekoontz1' \
		 --stringparam master 'eugenes-macbook-pro.local' \
		 --stringparam nn_failover '$(GUEST)' \
		 --stringparam jn1 'eugenes-macbook-pro.local' \
		 --stringparam zk1 'eugenes-macbook-pro.local' $^ | xmllint --format - > $@

ha-core-site.xml: templates/ha-core-site.xsl core-site.xml
	DNS_SERVER_NAME=$(GUEST) \
        MASTER=$(MASTER) \
	xsltproc --stringparam cluster 'ekoontz1' \
		 --stringparam master 'eugenes-macbook-pro.local' \
		 --stringparam nn_failover '$(GUEST)' \
		 --stringparam jn1 'eugenes-macbook-pro.local' \
		 --stringparam zk1 'eugenes-macbook-pro.local' $^ | xmllint --format - > $@

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

install: all rm-hadoop-runtime-symlink ~/hadoop-runtime services.keytab ~/hadoop-runtime/logs
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

install-ha: ha-install

ha-install: install ha-hdfs-site.xml ha-core-site.xml ~/hadoop-runtime/logs
	cp ha-hdfs-site.xml ~/hadoop-runtime/etc/hadoop/hdfs-site.xml
	cp ha-core-site.xml ~/hadoop-runtime/etc/hadoop/core-site.xml

rm-hadoop-runtime-symlink:
	-rm ~/hadoop-runtime

~/hadoop-runtime/logs:
	mkdir ~/hadoop-runtime/logs

#note 'head -n 1': in case of multiple directories in hadoop-dist/target, just take first one.
~/hadoop-runtime:
	ln -s `find $(HOME)/hadoop-common/hadoop-dist/target -name "hadoop*"  -type d -maxdepth 1 |head -n 1` $(HOME)/hadoop-runtime

stop: stop-hdfs stop-yarn stop-zookeeper
	echo
# ^^^ need a dummy action here (e.g. an echo) to avoid default action -
# default action is "cat stop.sh > stop", for some reason.)

stop-on-guest:
	ssh $(GUEST) "cd hadoop-conf && make stop"

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

format-nn: initialize-hdfs

format-dn:
	rm -rf /tmp/hadoop-data/dfs/data

start-nn: start-namenode

format-and-start-master:
	~/hadoop-runtime/bin/hdfs namenode -format -force

start-standby-nn-on-host: bootstrap-host-by-guest start-nn

start-standby-nn-on-guest: bootstrap-guest-by-host start-nn

format-and-start-jn: format-jn start-jn

bootstrap-guest-by-host:
	-rm -rf /tmp/hadoop-data/dfs/name
	mkdir -p /tmp/hadoop-data/dfs
	scp -r eugenes-macbook-pro.local:/tmp/hadoop-data/dfs/name /tmp/hadoop-data/dfs
#someday instead of the above we will simply do:
#       hdfs namenode -bootstrapStandby

bootstrap-host-by-guest:
	-rm -rf /tmp/hadoop-data/dfs/name
	mkdir -p /tmp/hadoop-data/dfs/name
	-rm -rf /tmp/hadoop/dfs/name
	mkdir -p /tmp/hadoop/dfs/name
	scp -r $(GUEST):/tmp/hadoop-data/dfs/name/current /tmp/hadoop-data/dfs/name
	scp -r $(GUEST):/tmp/hadoop-data/dfs/name/current /tmp/hadoop/dfs/name
#someday instead of the above we will simply do:
#       hdfs namenode -bootstrapStandby

start-namenode: services.keytab /tmp/hadoop-data/dfs/name $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/namenode.log
	echo "logging to $(HADOOP_RUNTIME)/logs/namenode.log"
	tail -f $(HADOOP_RUNTIME)/logs/namenode.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=namenode.log $(HADOOP_RUNTIME)/bin/hdfs namenode

start-nn-b: services.keytab /tmp/hadoop-data/dfs/name
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=namenode.log $(HADOOP_RUNTIME)/bin/hdfs namenode &


restart-zkfc: stop-zkfc start-zkfc

start-zkfc: services.keytab /tmp/hadoop-data/dfs/name $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/zkfc.log
	echo "logging to $(HADOOP_RUNTIME)/logs/zkfc.log"
	touch $(HADOOP_RUNTIME)/logs/zkfc.log && tail -f $(HADOOP_RUNTIME)/logs/zkfc.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=zkfc.log $(HADOOP_RUNTIME)/bin/hdfs zkfc

stop-zkfc:
	-kill `jps | grep DFSZKFailoverController | awk '{print $$1}'`

format-zkfc: services.keytab /tmp/hadoop-data/dfs/name
	$(HADOOP_RUNTIME)/bin/hdfs zkfc -formatZK

start-zk: services.keytab /tmp/hadoop-data/dfs/name
	~/zookeeper/bin/zkServer.sh start-foreground

format-nn-master:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -initializeSharedEdits

format-nn-failover:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format -clusterid ekoontz1 -force

start-nn: start-namenode

stop-namenode:
	kill `jps | grep NameNode | awk '{print $$1}'`

init-jn:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -initializeSharedEdits

format-and-start-jn: format-jn start-jn

format-jn:
	rm -rf /tmp/hadoop/dfs/jn
	mkdir /tmp/hadoop/dfs/jn
	find /tmp/hadoop/dfs/jn -ls
	rm -rf /tmp/hadoop-data/dfs/jn
	mkdir /tmp/hadoop-data/dfs/jn
	find /tmp/hadoop-data/dfs/jn -ls
	rm -rf /tmp/hadoop/dfs/journalnode
	mkdir /tmp/hadoop/dfs/journalnode
	find /tmp/hadoop/dfs/journalnode -ls
	rm -rf /tmp/hadoop/dfs/journalnode
	mkdir /tmp/hadoop/dfs/journalnode
	find /tmp/hadoop/dfs/journalnode -ls

#adding '/tmp/hadoop/dfs/name' as a dep causes a cycle because it will try to 
#do 'namenode -format' to create /tmp/hadoop/dfs/name. Then the namenode tries
#start-jn: services.keytab /tmp/hadoop/dfs/name
start-jn: services.keytab $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/journalnode.log
	echo "logging to: $(HADOOP_RUNTIME)/logs/journalnode.log"
	tail -f $(HADOOP_RUNTIME)/logs/journalnode.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=journalnode.log $(HADOOP_RUNTIME)/bin/hdfs journalnode

start-jn-b: services.keytab
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=journalnode.log $(HADOOP_RUNTIME)/bin/hdfs journalnode &

stop-jn:
	kill `jps | grep JournalNode | awk '{print $$1}'`

/tmp/hadoop/dfs/name:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format

start-secondary-namenode: services.keytab
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=secondarynamenode.log $(HADOOP_RUNTIME)/bin/hdfs secondarynamenode &

start-dn: start-datanode
stop-dn: stop-datanode

start-datanode: services.keytab  $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/datanode.log
	echo "logging to $(HADOOP_RUNTIME)/logs/datanode.log"
	tail -f $(HADOOP_RUNTIME)/logs/datanode.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=datanode.log $(HADOOP_RUNTIME)/bin/hdfs datanode

start-dn-b: services.keytab
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=datanode.log $(HADOOP_RUNTIME)/bin/hdfs datanode &

stop-datanode:
	kill `jps | grep DataNode | awk '{print $1}'`

start-yarn: stop-yarn start-resourcemanager start-nodemanager

start-resourcemanager:
	YARN_ROOT_LOGGER=INFO,DRFA YARN_LOGFILE=resourcemanager.log $(HADOOP_RUNTIME)/bin/yarn resourcemanager &

start-nodemanager:
	YARN_ROOT_LOGGER=INFO,DRFA YARN_LOGFILE=nodemanager.log $(HADOOP_RUNTIME)/bin/yarn nodemanager &

start-zookeeper:
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start

restart: stop start
	echo

restart-hdfs: stop-hdfs start-hdfs

start: sync services.keytab start-hdfs start-yarn start-zookeeper
	jps

start2: manualsync services.keytab start-hdfs start-yarn start-zookeeper

manualsync:
	ssh -t $(DNS_SERVER) "sudo date `date '+%m%d%H%M%Y.%S'`"

sync-time-of-dns-server:
	export DNS_SERVER=$(DNS_SERVER)	; make -s -e sync

# restart ntpdate and krb5kdc on server.
sync:
	ssh -t $(DNS_SERVER) "sudo service ntpdate restart"
	ssh -t $(DNS_SERVER) "sudo service krb5kdc restart"

# uses password authentication:
relogin: logout login

logout:
	-kdestroy

# check for login with klist: if it fails, login to kerberos with kinit.
login:
	klist | grep `whoami` 2>/dev/null || (export KRB5_CONFIG=$(KRB5_CONFIG); kinit `whoami`@$(REALM))

# uses keytab authentication.
hdfsuser: services.keytab
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit -k -t services.keytab hdfs/$(MASTER_HOST)@$(REALM)

rmr-tmp: hdfsuser
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp

rmr-tmp-ha: hdfsuser
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(CLUSTER):8020/tmp

# this modifies HDFS permissions so that normal user can run jobs.
permissions: rmr-tmp
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp

	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/user
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/user

	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp/yarn
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp/yarn
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp/yarn

	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(MASTER):8020/

permissions-ha: rmr-tmp-ha
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(CLUSTER):8020/tmp

	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/user
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(CLUSTER):8020/user

	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp/yarn
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/tmp/yarn
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(CLUSTER):8020/tmp/yarn

	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(CLUSTER):8020/

#print some diagnostics
report:
	export CLUSTER=$(CLUSTER) MASTER=$(MASTER) REALM=$(REALM) DNS_SERVER=$(DNS_SERVER) HADOOP_RUNTIME=$(HADOOP_RUNTIME); make -s -e report2

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
	echo " JPS (Java processes running):"
	echo `jps`

test:
	export MASTER=$(MASTER); make -s -e runtest

runtest: test-hdfs test-mapreduce

test-hdfs: login permissions
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls hdfs://$(MASTER):8020/

test-hdfs-ha: login permissions-ha
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls hdfs://ekoontz1:8020/

#test hdfs HA, but no login or permissions-checking: faster.
test-hdfs-han: 
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(CLUSTER):8020/
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp/*
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/tmp/
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -copyFromLocal ~/hadoop-runtime/logs/* hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(CLUSTER):8020/

test-mapreduce: login
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/user/`whoami`/*
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop jar \
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

prep-active-for-sb-bootstrap:
	~/hadoop-runtime/bin/hdfs dfsadmin -safemode enter
	~/hadoop-runtime/bin/hdfs dfsadmin -saveNamespace

build:
	pushd . && cd ~/hadoop-common && mvn -Pdist -DskipTests package && popd

format-and-start-master: format-master start-nn

format-and-start-dn: format-dn start-dn

format-master:
	~/hadoop-runtime/bin/hdfs namenode -format -force

clean-logs:
	-rm ~/hadoop-runtime/logs/*

touch-logs:
	touch ~/hadoop-runtime/logs/datanode.log ~/hadoop-runtime/logs/zkfc.log 

touch-logs-on-guest:
	ssh $(GUEST) "cd hadoop-conf && make touch-logs"


terms: stop stop-on-guest sync touch-logs touch-logs-on-guest terms.rb
	./terms.rb eugene.yaml
	./terms.scpt

