<?xml version="1.0" encoding="UTF-8"?>
<!--
  Topic pull override for org.dita-community.codeinclude.

  With build-step.coderef=false, coderef elements are still in the topics
  when topicpull runs. coderef is an xref specialization, so topicpull would
  try to resolve each one as a link and report DOTX031E for every local code
  file. Pass coderef through untouched; codeinclude.process resolves it later.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                exclude-result-prefixes="#all">

  <xsl:template match="*[contains(@class, ' pr-d/coderef ')]" priority="20">
    <xsl:copy-of select="."/>
  </xsl:template>

</xsl:stylesheet>
