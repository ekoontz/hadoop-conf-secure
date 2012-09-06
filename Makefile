.PHONY=all clean install start start-yarn start-hdfs start-zookeeper test test-hdfs test-mapreduce kill principals printenv \
 envquiet normaluser hdfsuser kill kill-hdfs kill-yarn kill-zookeeper
# ^^ TODO: add test-zookeeper.

# config files that are rewrittten by rewrite-config.xsl.
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties hadoop-env.sh yarn-env.sh hadoop-conf.sh

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/tmp/hadoop-data
MASTER=`hostname -f | tr "[:upper:]" "[:lower:]"`
HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper
REALM=EXAMPLE.COM
KRB5_CONFIG=./krb5.conf
KADMIN_LOCAL="ssh 172.16.175.3 'sudo kadmin.local'"
all: $(CONFIGS)

printenv:
	make -s -e envquiet

envquiet:
	echo "Hadoop Runtime directory:     $(HADOOP_RUNTIME)"
	echo "Zookeeper Runtime directory:  $(ZOOKEEPER_HOME)"
	echo "Master hostname:              $(MASTER)"
	echo "Tmp directory:                $(TMPDIR)"
	echo "Realm name:                   $(REALM)"

principals:
	export KRB5_CONFIG=$(KRB5_CONFIG); export MASTER=$(MASTER); sh principals.sh

install: clean all ~/hadoop-runtime
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

~/hadoop-runtime:
	ln -s `find $(HOME)/hadoop-common/hadoop-dist/target -name "hadoop*"  -type d -maxdepth 1` $(HOME)/hadoop-runtime

#add kill-hdfs and kill-yarn as sub-targets.

kill: kill-hdfs kill-yarn kill-zookeeper
	echo
# ^^^ need a dummy action here (e.g. an echo) to avoid default action (cat kill.sh > kill, for some reason.)

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
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start-foreground 

start: kill start-hdfs start-yarn start-zookeeper

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
debug:
	echo "MASTER:         " $(MASTER)
	echo "REALM:          " $(REALM)
	echo "HADOOP_RUNTIME: " $(HADOOP_RUNTIME)

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
	-rm $(CONFIGS)

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

