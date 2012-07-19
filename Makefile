.PHONY=all clean install
CONFIGS=core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml

# TMPDIR: Should be on a filesystem big enough to do your hadoop work.
TMPDIR=/work/tmp
MASTER=`hostname -f`

all: $(CONFIGS)

install: clean all
	cp $(CONFIGS) ~/hadoop-runtime/etc/hadoop

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


