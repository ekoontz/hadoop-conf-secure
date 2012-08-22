<!-- Localize hostnames and other values in hadoop files depending on environment that we are called with. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="hostname"/>
  <xsl:param name="tmpdir"/>
  <xsl:param name="homedir"/>
  <xsl:param name="realm"/>

  <xsl:template match="configuration">
    <xsl:copy select=".">
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property|name|value">
    <xsl:copy select=".">
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.resourcemanager.scheduler.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>
      </value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='hadoop.tmp.dir']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$tmpdir"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.resourcemanager.resource-tracker.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(value,':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.resourcemanager.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(value,':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.resourcemanager.admin.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(value,':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.resourcemanager.webapp.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(value,':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='dfs.http.address']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(value,':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='fs.default.name']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="substring-before(value,':')"/>://<xsl:value-of select="$hostname"/>:<xsl:value-of select="substring-after(substring-after(value,':'),':')"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <!-- following might be collapsable into a single rule using the '|' xpath operator. -->
  <xsl:template match="property[name/text()='dfs.namenode.keytab.file']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='dfs.datanode.keytab.file']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='yarn.resourcemanager.keytab']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='yarn.nodemanager.keytab']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='mapreduce.jobtracker.keytab']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='mapreduce.tasktracker.keytab']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-conf/services.keytab</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='dfs.namenode.kerberos.principal']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>hdfs/_HOST@<xsl:value-of select="$realm"/></value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='dfs.datanode.kerberos.principal']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>hdfs/_HOST@<xsl:value-of select="$realm"/></value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='yarn.resourcemanager.principal']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>yarn/_HOST@<xsl:value-of select="$realm"/></value>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="property[name/text()='yarn.nodemanager.principal']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>yarn/_HOST@<xsl:value-of select="$realm"/></value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='hadoop.tmp.dir']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$tmpdir"/>
      </value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.application.classpath']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value><xsl:value-of select="$homedir"/>/hadoop-runtime/etc/hadoop:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/common/*:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/common/lib/*:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/hdfs/*:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/hdfs/lib/*:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/mapreduce/*:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/mapreduce/lib/*:<xsl:value-of select="$homedir"/>/giraph/target/classes:<xsl:value-of select="$homedir"/>/hadoop-runtime/share/hadoop/yarn/*:<xsl:value-of select="$homedir"/>/.m2/repository/org/json/json/20090211/json-20090211.jar:<xsl:value-of select="$homedir"/>/.m2/repository/org/json/json/20090211/json-20090211.jar:/Users/ekoontz/.m2/repository/net/iharder/base64/2.3.8/base64-2.3.8.jar:</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.nodemanager.admin-env']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>MALLOC_ARENA_MAX=$MALLOC_ARENA_MAX, JAVA_LIBRARY_PATH=$JAVA_LIBRARY_PATH, LD_LIBRARY_PATH=$JAVA_LIBRARY_PATH, FOO=42, KRB5_CONFIG=/Users/ekoontz/pig/krb5.conf</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='yarn.app.mapreduce.am.command-opts']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5011 -Dfoo=44 -Dhadoop.root.logger=INFO,CLA -Dzookeeper.root.logger=INFO,CLA -Djava.security.krb5.conf=/Users/ekoontz/pig/krb5.conf -Dsun.security.krb5.debug=true  -Dsun.net.spi.nameservice.nameservers=172.16.175.3 -Dsun.net.spi.nameservice.provider.1=dns,sun</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='mapreduce.admin.map.child.java.opts']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>-Dhadoop.root.logger=INFO,CLA -Dzookeeper.root.logger=INFO,CLA -Dfoo=45 -Djava.security.krb5.conf=/Users/ekoontz/pig/krb5.conf -Dsun.security.krb5.debug=true  -Dsun.net.spi.nameservice.nameservers=172.16.175.3 -Dsun.net.spi.nameservice.provider.1=dns,sun</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='mapreduce.reduce.java.opts']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>-Dhadoop.root.logger=INFO,CLA -Dzookeeper.root.logger=INFO,CLA -Dfoo=45 -Djava.security.krb5.conf=/Users/ekoontz/pig/krb5.conf -Dsun.security.krb5.debug=true  -Dsun.net.spi.nameservice.nameservers=172.16.175.3 -Dsun.net.spi.nameservice.provider.1=dns,sun</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="property[name/text()='mapreduce.map.java.opts']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>-Dhadoop.root.logger=INFO,CLA -Dzookeeper.root.logger=INFO,CLA -Dfoo=45 -Djava.security.krb5.conf=/Users/ekoontz/pig/krb5.conf -Dsun.security.krb5.debug=true  -Dsun.net.spi.nameservice.nameservers=172.16.175.3 -Dsun.net.spi.nameservice.provider.1=dns,sun</value>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="comment()">
    <xsl:copy-of select="."/>
  </xsl:template>


</xsl:stylesheet>
