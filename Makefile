.PHONY=all clean install start test kill principals
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml
# config files that only need to be copied rather than modified-by-
# xsl-and-copied.
OTHER_CONFIGS=log4j.properties

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/tmp/hadoop-data
MASTER=`hostname -f`
HADOOP_RUNTIME=$(HOME)/hadoop-runtime
ZOOKEEPER_HOME=$(HOME)/zookeeper

all: $(CONFIGS)

principals:
	sh principals.sh

install: clean all
	cp $(CONFIGS) $(OTHER_CONFIGS) ~/hadoop-runtime/etc/hadoop

kill: 
	-sh kill.sh

start: kill
	-rm -rf /tmp/logs
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format
	$(HADOOP_RUNTIME)/bin/hdfs namenode &
	$(HADOOP_RUNTIME)/bin/hdfs datanode &
	$(HADOOP_RUNTIME)/bin/yarn resourcemanager &
	$(HADOOP_RUNTIME)/bin/yarn nodemanager &
	$(ZOOKEEPER_HOME)/bin/zkServer.sh start-foreground 

test:
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.0.1.tm6.jar pi 5 5

clean:
	-rm $(CONFIGS)

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` \
                 --stringparam tmpdir $(TMPDIR) rewrite-hosts.xsl $^  | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` rewrite-hosts.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` \
	         --stringparam homedir `echo $$HOME` rewrite-hosts.xsl $^ | xmllint --format - > $@

