<!-- Localize hostnames and other values in hadoop files depending on environment that we are called with. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="hostname"/>
  <xsl:param name="tmpdir"/>
  <xsl:param name="homedir"/>

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


  <xsl:template match="property[name/text()='hadoop.tmp.dir']">
    <xsl:copy select=".">
      <name><xsl:value-of select="name"/></name>
      <value>
	<xsl:value-of select="$tmpdir"/>
      </value>
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
