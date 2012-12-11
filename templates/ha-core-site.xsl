<?xml version="1.0"?>
<!-- Transform a hdfs-site.xml into high-availability mode. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="cluster"/>
  <xsl:param name="master"/>
  <xsl:param name="nn_failover"/>
  <xsl:param name="jn1"/>
  <xsl:param name="zk1"/>

  <xsl:template match="/configuration">
    <configuration>
      <xsl:apply-templates/>

      <!-- Hadoop Ops book (p106) recommends that this goes in core-site.xml (as opposed to hdfs-site.xml). -->
      <property>
	<name>ha.zookeeper.quorum</name>
	<value><xsl:value-of select="$zk1"/>:2181</value>
      </property>

    </configuration>
  </xsl:template>

  <xsl:template match="property[name='fs.default.name' or name='fs.defaultFS']">
    <property>
      <name>fs.defaultFS</name>
      <value>hdfs://<xsl:value-of select="$cluster"/>:8020</value>
    </property>
  </xsl:template>

  <xsl:template match="property|name|value">
    <xsl:copy select=".">
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

