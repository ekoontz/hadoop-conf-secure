.PHONY=all clean install start start-yarn start-hdfs start-zookeeper test test-hdfs test-mapreduce kill principals printenv \
 envquiet normaluser hdfsuser kill kill-hdfs kill-yarn kill-zookeeper report report2 sync

# ^^ TODO: add test-zookeeper.

# config files that are rewritten by rewrite-config.xsl.
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties hadoop-env.sh yarn-env.sh hadoop-conf.sh services.keytab

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/tmp/hadoop-data

#this is kind of crazy, sorry. would like a simpler way.
MASTER=`export MASTER=\`echo \`\`hostname -f | tr "[:upper:]" "[:lower:]"\`\`\`; echo $$MASTER`
HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper
REALM=EXAMPLE.COM
KRB5_CONFIG=./krb5.conf
DNS_SERVER=172.16.175.3
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

install: clean all ~/hadoop-runtime services.keytab
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

~/hadoop-runtime:
	ln -s `find $(HOME)/hadoop-common/hadoop-dist/target -name "hadoop*"  -type d -maxdepth 1` $(HOME)/hadoop-runtime

#add kill-hdfs and kill-yarn as sub-targets.

kill: kill-hdfs kill-yarn kill-zookeeper
	echo
# ^^^ need a dummy action here (e.g. an echo) to avoid default action -
# default action is "cat kill.sh > kill", for some reason.)

kill-hdfs: 
	-sh kill.sh hdfs

kill-yarn:
	-sh kill.sh yarn

kill-zookeeper:
	-sh kill.sh zookeeper

start-hdfs: kill-hdfs
	-rm -rf /tmp/logs
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format
	$(HADOOP_RUNTIME)/bin/hdfs namenode &
	$(HADOOP_RUNTIME)/bin/hdfs datanode &

start-yarn: kill-yarn
	$(HADOOP_RUNTIME)/bin/yarn resourcemanager &
	$(HADOOP_RUNTIME)/bin/yarn nodemanager &

start-zookeeper:
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start

start: kill start-hdfs start-yarn start-zookeeper

# restart ntpdate and krb5kdc on server.
sync:
	ssh -t $(DNS_SERVER) "sudo service ntpdate restart"
	ssh -t $(DNS_SERVER) "sudo service krb5kdc restart"

# use password authentication.
normaluser:
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit `whoami`@$(REALM)

# use keytab authentication.
hdfsuser:
	-kdestroy
	export KRB5_CONFIG=$(KRB5_CONFIG); kinit -k -t services.keytab hdfs/$(MASTER)@$(REALM)

# this modifies HDFS permissions so that normal user can run jobs.
permissions: hdfsuser
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
	echo "   HADOOP_RUNTIME DIR:             $(HADOOP_RUNTIME)"
	echo " DNS:"
	echo "  DNS_SERVER:                      $(DNS_SERVER)"
	echo "  DNS CLIENT:"
	echo "   MASTER DNS LOOKUP $(MASTER): `dig @$(DNS_SERVER) $(MASTER) +short`"
	export MASTER_IP=`dig @$(DNS_SERVER) $(MASTER) +short`; echo "   REVERSE MASTER DNS LOOKUP $(MASTER): `dig @$(DNS_SERVER) -x $$MASTER_IP +short`"
	echo " DATE:"
	echo "  MASTER DATE:                    " `date`
	echo "  DNS_SERVER DATE:                " `ssh $(DNS_SERVER) date`
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

test: hdfs-test mapreduce-test

test-hdfs: permissions normaluser
	$(HADOOP_RUNTIME)/bin/hadoop fs -ls hdfs://$(MASTER):8020/

test-mapreduce: normaluser
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar pi 5 5

#deprecated.
hdfs-test: test-hdfs
mapreduce-test: test-mapreduce

clean:
	-rm $(CONFIGS) services.keytab

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-config.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` \
	         --stringparam realm $(REALM) \
                 --stringparam tmpdir $(TMPDIR) rewrite-config.xsl $^  | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` rewrite-config.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam realm $(REALM) \
	         --stringparam homedir `echo $$HOME` rewrite-config.xsl $^ | xmllint --format - > $@

