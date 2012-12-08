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

      <!-- begin HA configuration -->
      <property>
	<name>dfs.namenode.rpc-address.<xsl:value-of select="$cluster"/>.nn1</name>
	<value><xsl:value-of select="$master"/>:8020</value>
      </property>
      <property>
	<name>dfs.namenode.rpc-address.<xsl:value-of select="$cluster"/>.nn2</name>
	<value><xsl:value-of select="$nn_failover"/>:8020</value>
      </property>
      <property>
	<name>dfs.namenode.http-address.<xsl:value-of select="$cluster"/>.nn1</name>
	<value><xsl:value-of select="$master"/>:8070</value>
      </property>
      <property>
	<name>dfs.namenode.http-address.<xsl:value-of select="$cluster"/>.nn2</name>
	<value><xsl:value-of select="$nn_failover"/>:8070</value>
      </property>
      <property>
	<name>dfs.namenode.https-address.<xsl:value-of select="$cluster"/>.nn1</name>
	<value><xsl:value-of select="$master"/>:8090</value>
      </property>
      <property>
	<name>dfs.namenode.https-address.<xsl:value-of select="$cluster"/>.nn2</name>
	<value><xsl:value-of select="$nn_failover"/>:8090</value>
      </property>
      <property>
	<name>dfs.nameservices</name>
	<value><xsl:value-of select="$cluster"/></value>
      </property>

      <property>
	<name>dfs.ha.namenodes.<xsl:value-of select="$cluster"/></name>
	<value>nn1,nn2</value>
      </property>

      <property>
	<name>dfs.namenode.rpc-address.<xsl:value-of select="$cluster"/>.nn1</name>
	<value><xsl:value-of select="$master"/>:8020</value>
      </property>

      <property>
	<name>dfs.namenode.rpc-address.<xsl:value-of select="$cluster"/>.nn2</name>
	<value><xsl:value-of select="$nn_failover"/>:8020</value>
      </property>

      <property>
	<name>dfs.client.failover.proxy.provider.<xsl:value-of select="$cluster"/></name>
	<value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
      </property>

      <property>
	<name>dfs.ha.automatic-failover.enabled</name>
	<value>true</value>
      </property>

      <property>
	<name>dfs.journalnode.keytab.file</name>
	<value>/Users/ekoontz/hadoop-conf/services.keytab</value>
      </property>

      <property>
	<name>dfs.journalnode.kerberos.principal</name>
	<value>HTTP/_HOST@EXAMPLE.COM</value>
      </property>

      <property>
	<name>dfs.journalnode.kerberos.internal.spnego.principal</name>
	<value>HTTP/_HOST@EXAMPLE.COM</value>
      </property>

<!--      <property>
	<name>dfs.journalnode.edits.dir</name>
	<value>/media/ephemeral0/dfs/jn</value>
      </property> -->

      <!-- http://grokbase.com/t/cloudera/cdh-user/12anhyr8ht/cdh4-failover-controllers#20121023kf2jmn330yqtdh34m1c7q5hw9m -->
      <!-- https://issues.apache.org/jira/secure/attachment/12547598/qjournal-design.pdf p.18 -->
      <property>
	<name>dfs.ha.fencing.methods</name>
	<value>shell(/bin/true)</value>
      </property>

      <!-- https://ccp.cloudera.com/display/CDH4DOC/Software+Configuration+for+Quorum-based+Storage -->
      <property>
	<name>dfs.namenode.shared.edits.dir</name>
	<value>qjournal://<xsl:value-of select="$jn1"/>:8485/<xsl:value-of select="$cluster"/></value>
      </property>

      <!-- TODO: Hadoop Ops book (p106) recommends that this goes in core-site.xml. -->
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

  <xsl:template match="property[name='dfs.namenode.kerberos.https.principal']">
    <property>
      <xsl:copy-of select="name"/>
      <value>HTTP/_HOST@EXAMPLE.COM</value>
    </property>
  </xsl:template>

  <xsl:template match="property[name='dfs.datanode.kerberos.https.principal']">
    <property>
      <xsl:copy-of select="name"/>
      <value>HTTP/_HOST@EXAMPLE.COM</value>
    </property>
  </xsl:template>

  <!-- these 2 not used with TM-6 (TODO: make part of upgrade.xsl as mentioned above) -->
  <xsl:template match="property[name='dfs.http.address']"/>
  <xsl:template match="property[name='dfs.https.address']"/>

  <!-- with HA, no secondary namenode. -->
  <xsl:template match="property[name='dfs.secondary.namenode.kerberos.https.principal']"/>
  <xsl:template match="property[name='dfs.secondary.namenode.kerberos.principal']"/>
  <xsl:template match="property[name='dfs.secondary.namenode.keytab.file']"/>
  <xsl:template match="property[name='dfs.secondary.namenode.user.name']"/>
  <xsl:template match="property[name='dfs.secondary.http.address']"/>
  <xsl:template match="property[name='dfs.secondary.http.port']"/>
  <xsl:template match="property[name='dfs.secondary.https.address']"/>
  <xsl:template match="property[name='dfs.secondary.https.port']"/>

  <!-- remove any existing HA properties: use our own (given above) -->
  <xsl:template match="property[name='dfs.nameservices']"/>
  <xsl:template match="property[substring(name,0,7)='dfs.ha']"/>
  <xsl:template match="property[substring(name,0,26)='dfs.namenode.rpc-address.']"/>
  <xsl:template match="property[substring(name,0,21)='dfs.client.failover.']"/>
  <xsl:template match="property[substring(name,0,16)='dfs.journalnode']"/>
  <xsl:template match="property[substring(name,0,26)='dfs.namenode.shared.edits']"/>

  <xsl:template match="property|name|value">
    <xsl:copy select=".">
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

