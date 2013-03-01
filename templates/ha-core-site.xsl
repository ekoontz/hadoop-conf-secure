<?xml version="1.0"?>
<!-- Transform a hdfs-site.xml into high-availability mode. -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="cluster"/>
  <xsl:param name="master"/>
  <xsl:param name="nn_failover"/>
  <xsl:param name="jn1"/>
  <xsl:param name="ldap_server"/>
  <xsl:param name="zk1"/>

  <xsl:template match="/configuration">
    <configuration>
      <xsl:apply-templates/>

      <!-- Hadoop Ops book (p106) recommends that this goes in core-site.xml (as opposed to hdfs-site.xml). -->
      <property>
	<name>ha.zookeeper.quorum</name>
	<value><xsl:value-of select="$zk1"/>:2181</value>
      </property>

      <property>
	<name>hadoop.security.group.mapping</name>
	<value>org.apache.hadoop.security.LdapGroupsMapping</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.url</name>
	<value>ldap://xsl:vlaue-of select="$ldap_server"/>/</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.bind.user</name>
	<value>cn=Manager,dc=openiam,dc=org</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.bind.password</name>
	<value>foobar</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.base</name>
	<value>dc=openiam,dc=org</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.search.filter.user</name>
	<value>(&amp;(objectClass=account)(uid={0}))</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.search.filter.group</name>
	<value>(objectClass=groupOfNames)</value>
      </property>
      
      <property>
	<name>hadoop.security.group.mapping.ldap.search.attr.group.name</name>
	<value>cn</value>
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

