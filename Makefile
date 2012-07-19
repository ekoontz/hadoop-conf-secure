.PHONY=all clean install
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

all: $(CONFIGS)

install: clean all
	cp $(CONFIGS) ~/hadoop-runtime/etc/hadoop

clean:
	-rm $(CONFIGS)

core-site.xml: templates/core-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

hdfs-site.xml: templates/hdfs-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

mapred-site.xml: templates/mapred-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@

yarn-site.xml: templates/yarn-site.xml
	xsltproc --stringparam hostname `hostname -f` rewrite-hosts.xsl $^ | xmllint --format - > $@


