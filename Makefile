.PHONY=all clean install start test
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/work/tmp
MASTER=`hostname -f`
HADOOP_RUNTIME=$(HOME)/hadoop-runtime

all: $(CONFIGS)

install: clean all
	cp $(CONFIGS) ~/hadoop-runtime/etc/hadoop

start:
	-kill `ps -ef | grep java | grep apache | awk '{print $2}'`
	sleep 10
	cd $(HOME)/hadoop-runtime
	rm -rf $(TMPDIR)
	$(HADOOP_RUNTIME)/bin/hdfs namenode -format
	$(HADOOP_RUNTIME)/bin/hdfs namenode &
	$(HADOOP_RUNTIME)/bin/hdfs datanode &
	$(HADOOP_RUNTIME)/bin/yarn resourcemanager &
	$(HADOOP_RUNTIME)/bin/yarn nodemanager &
	$(HADOOP_RUNTIME)/bin/zkServer.sh start-foreground 

test:
	$(HADOOP_RUNTIME)/bin/hadoop jar \
         $(HADOOP_RUNTIME)/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.0.1.tm6.jar pi 5 5

clean:
	-rm $(CONFIGS)

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` \
                 --stringparam tmpdir $(TMPDIR) rewrite-hosts.xsl $^  | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@


