# with YARN:
#
# make stop sync format-zk prep-jn-dir start-hdfs-ha hdfs-test start-yarn mapreduce-test
#
# known to work:
#
# make stop sync format-zk prep-jn-dir start-hdfs-ha hdfs-test 
#  (type password)
#  then:
# make start-yarn test-mapreduce
#  (type password)
#
#  then:
# make hbase-setup
#
#  then:
# cd ~/hbase-runtime
# bin/hbase master start &
# bin/hbase regionserver start &

.PHONY=all clean install start restart start-hdfs start-zookeeper test test-hdfs test-mapreduce \
stop principals printenv start-namenode start-namenode-bg start-datanode start-datanode-bg initialize-hdfs \
envquiet login login-from-keytab relogin logout hdfsuser stop stop-hdfs stop-yarn stop-zookeeper report report2 \
sync runtest manualsync start-resourcemanager start-nodemanager restart-hdfs test-terasort test-terasort2 \
stop-secondarynamenode rm-hadoop-runtime-symlink ha-install start-jn build clean-logs terms stop-on-guest \
touch-logs touch-logs-on-guest start-ha ha start-hdfs-ha start-yarn stop-yarn restart-yarn hdfs-login

# ^^ TODO: add test-zookeeper target and add it to .PHONY above

# config files that are rewritten by rewrite-config.xsl.
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml ha-hdfs-site.xml ha-core-site.xml hadoop-policy.xml container-log4j.properties
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

ha:
	make install-ha stop start-ha
	ssh $(GUEST) "cd hadoop-conf ; export JAVA_HOME=/usr/lib/jvm/java-openjdk; make -e stop bootstrap-guest-by-host format-zkfc start-zkfc-bg start-nn" &

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
		 --stringparam zk1 'eugenes-macbook-pro.local' \
		 --stringparam ldap_server '$(GUEST)' $^ | xmllint --format - > $@

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
	ssh -t $(DNS_SERVER) "sh principals.sh $(MASTER_HOST)"
	scp $(DNS_SERVER):services.keytab .

user.keytab:
	scp user-keytab.sh $(DNS_SERVER):
	ssh -t $(DNS_SERVER) "sh user-keytab.sh `whoami`"
	scp $(DNS_SERVER):`whoami`.keytab $@

install: all rm-hadoop-runtime-symlink ~/hadoop-runtime services.keytab ~/hadoop-runtime/logs install_zoo_cfg
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

install_zoo_cfg: zoo.cfg
	-mkdir -p ~/zookeeper/conf
	cp zoo.cfg ~/zookeeper/conf

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

start-hdfs: stop-hdfs initialize-hdfs start-namenode-bg start-datanode-bg

restart-hdfs-ha: stop-hdfs start-hdfs-ha

start-hdfs-ha: start-jn-b initialize-hdfs start-zookeeper start-namenode-bg format-zkfc start-zkfc-bg start-datanode-bg

initialize-hdfs:
	-rm -rf /tmp/logs
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format

format-nn: initialize-hdfs

format-dn:
	rm -rf /tmp/hadoop-data/dfs/data

/tmp/hadoop-data/dfs/name:
	-mkdir $@

start-nn: start-namenode

format-and-start-master:
	~/hadoop-runtime/bin/hdfs namenode -format -force

start-standby-nn-on-host: bootstrap-host-by-guest start-nn

# run this on guest, not host:
start-standby-nn-on-guest: bootstrap-guest-by-host start-nn

format-and-start-jn: prep-jn-dir start-jn

# run this on guest, not host:
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

start-namenode-bg: services.keytab /tmp/hadoop-data/dfs/name $(HADOOP_RUNTIME)/logs
	$(NAMENODE_OPTS) HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=namenode.log $(HADOOP_RUNTIME)/bin/hdfs namenode &

restart-zkfc: stop-zkfc start-zkfc

start-zkfc: services.keytab /tmp/hadoop-data/dfs/name $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/zkfc.log
	echo "logging to $(HADOOP_RUNTIME)/logs/zkfc.log"
	touch $(HADOOP_RUNTIME)/logs/zkfc.log && tail -f $(HADOOP_RUNTIME)/logs/zkfc.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=zkfc.log $(HADOOP_RUNTIME)/bin/hdfs zkfc

start-zkfc-bg: services.keytab /tmp/hadoop-data/dfs/name $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/zkfc.log
	echo "logging to $(HADOOP_RUNTIME)/logs/zkfc.log"
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=zkfc.log $(HADOOP_RUNTIME)/bin/hdfs zkfc &

stop-zkfc:
	-kill `jps | grep DFSZKFailoverController | awk '{print $$1}'`

format-zkfc: services.keytab /tmp/hadoop-data/dfs/name
	$(HADOOP_RUNTIME)/bin/hdfs zkfc -formatZK

format-nn-master:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -initializeSharedEdits

format-nn-failover:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format -clusterid ekoontz1 -force

start-nn: start-namenode

stop-namenode:
	kill `jps | grep NameNode | awk '{print $$1}'`

init-jn:
	$(HADOOP_RUNTIME)/bin/hdfs namenode -initializeSharedEdits

format-and-start-jn: prep-jn-dir start-jn

prep-jn-dir:
	rm -rf /tmp/hadoop/dfs/jn
	mkdir -p /tmp/hadoop/dfs/jn
	find /tmp/hadoop/dfs/jn -ls
	rm -rf /tmp/hadoop-data/dfs/jn
	mkdir -p /tmp/hadoop-data/dfs/jn
	find /tmp/hadoop-data/dfs/jn -ls
	rm -rf /tmp/hadoop/dfs/journalnode
	mkdir -p /tmp/hadoop/dfs/journalnode
	find /tmp/hadoop/dfs/journalnode -ls
	rm -rf /tmp/hadoop/dfs/journalnode
	mkdir -p /tmp/hadoop/dfs/journalnode
	find /tmp/hadoop/dfs/journalnode -ls

#adding '/tmp/hadoop/dfs/name' as a dep causes a cycle because it will try to 
#do 'namenode -format' to create /tmp/hadoop/dfs/name. Then the namenode tries
#start-jn: services.keytab /tmp/hadoop/dfs/name
start-jn: services.keytab $(HADOOP_RUNTIME)/logs
	touch $(HADOOP_RUNTIME)/logs/journalnode.log
	echo "logging to: $(HADOOP_RUNTIME)/logs/journalnode.log"
	tail -f $(HADOOP_RUNTIME)/logs/journalnode.log &
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=journalnode.log $(HADOOP_RUNTIME)/bin/hdfs journalnode &

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

start-datanode-bg: services.keytab $(HADOOP_RUNTIME)/logs
	HADOOP_ROOT_LOGGER=INFO,DRFA HADOOP_LOGFILE=datanode.log $(HADOOP_RUNTIME)/bin/hdfs datanode &

stop-datanode:
	kill `jps | grep DataNode | awk '{print $1}'`

start-yarn: stop-yarn start-resourcemanager start-nodemanager

restart-yarn: start-yarn

start-resourcemanager:
	YARN_ROOT_LOGGER=INFO,DRFA YARN_LOGFILE=resourcemanager.log $(HADOOP_RUNTIME)/bin/yarn resourcemanager &

start-nodemanager:
	YARN_ROOT_LOGGER=INFO,DRFA YARN_LOGFILE=nodemanager.log $(HADOOP_RUNTIME)/bin/yarn nodemanager &

restart-zookeeper: stop-zookeeper start-zookeeper

format-zk: stop-zookeeper
	rm -rf /tmp/zookeeper/*

start-zk-fg: services.keytab /tmp/hadoop-data/dfs/name
	~/zookeeper/bin/zkServer.sh start-foreground

start-zk: services.keytab /tmp/hadoop-data/dfs/name
	~/zookeeper/bin/zkServer.sh start

start-zookeeper:
	SERVER_JVMFLAGS="-Dzookeeper.kerberos.removeHostFromPrincipal=true -Dzookeeper.kerberos.removeRealmFromPrincipal=true   -Djava.security.krb5.conf=$(HOME)/hadoop-conf/krb5.conf -Dsun.net.spi.nameservice.nameservers=172.16.175.3 -Dsun.net.spi.nameservice.provider.1=dns,sun -Djava.security.auth.login.config=/Users/ekoontz/hbase-runtime/conf/jaas.conf" ZOO_LOG_DIR=/tmp $(ZOOKEEPER_HOME)/bin/zkServer.sh start

restart-zookeeper: stop-zookeeper start-zookeeper

restart: stop start
	echo

restart-hdfs: stop-hdfs start-hdfs

start: sync services.keytab start-hdfs start-yarn start-zookeeper
	jps

start-ha: sync services.keytab prep-jn-dir start-hdfs-ha start-yarn start-zookeeper
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

relogin: logout login-from-keytab

logout:
	-kdestroy

# check for login with klist: if it fails, login to kerberos with kinit.
login: logout
	klist | grep `whoami` 2>/dev/null || (export KRB5_CONFIG=$(KRB5_CONFIG); kdestroy; kinit `whoami`@$(REALM))

login-from-keytab: logout user.keytab
	klist | grep `whoami` 2>/dev/null || (export KRB5_CONFIG=$(KRB5_CONFIG); kdestroy; kinit -k -t user.keytab `whoami`@$(REALM))


hdfs-login: hdfsuser

# uses keytab authentication.
hdfsuser: services.keytab
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit -k -t services.keytab hdfs/$(MASTER_HOST)@$(REALM)

hbase-login: services.keytab
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit -k -t services.keytab hbase/$(MASTER_HOST)@$(REALM)


rmr-tmp: hdfsuser
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(MASTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 hdfs://$(MASTER):8020/tmp

rmr-tmp-ha: hdfsuser
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/home/hdfs/*
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
	export CLUSTER=$(CLUSTER) MASTER=$(MASTER_HOST) REALM=$(REALM) DNS_SERVER=$(DNS_SERVER) HADOOP_RUNTIME=$(HADOOP_RUNTIME); make -s -e report2

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

test-hdfs: permissions
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls hdfs://$(MASTER):8020/

#test hdfs HA, but no login or permissions-checking: faster.
test-hdfs-han: 
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(CLUSTER):8020/
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -rm -r hdfs://$(CLUSTER):8020/tmp/*
	-$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -mkdir hdfs://$(CLUSTER):8020/tmp/
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -copyFromLocal ~/hadoop-runtime/logs/* hdfs://$(CLUSTER):8020/tmp
	$(LOG) $(HADOOP_RUNTIME)/bin/hadoop fs -ls -R hdfs://$(CLUSTER):8020/

test-mapreduce: relogin
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

hbase-setup: hdfs-login
	$(HADOOP_RUNTIME)/bin/hadoop fs -mkdir -p /hbase
	$(HADOOP_RUNTIME)/bin/hadoop fs -chown hbase /hbase
	$(HADOOP_RUNTIME)/bin/hadoop fs -chmod 777 /tmp/hadoop-yarn
