<!-- convert hosts in hadoop files from one hostname to another -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="hostname"/>

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
