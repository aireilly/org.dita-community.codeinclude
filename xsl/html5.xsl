<?xml version="1.0" encoding="UTF-8"?>
<!--
  HTML5 rendering for org.dita-community.codeinclude.

  * <code> inside a codeblock with a language gets class="language-x" and
    data-language="x", the convention used by highlight.js and Prism, in
    case you prefer to highlight in the browser (set codeinclude.highlight=no).
  * Pages that contain build-time highlighted code get a small embedded
    stylesheet (switch off with codeinclude.html.css=none and style the
    .hl-* classes in your own args.css instead).
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ci="urn:dita-community:codeinclude"
                exclude-result-prefixes="#all">

  <xsl:param name="codeinclude.html.css" as="xs:string" select="'inline'"/>

  <xsl:function name="ci:codeblock-language" as="xs:string?">
    <xsl:param name="codeblock" as="element()"/>
    <xsl:sequence select="(tokenize(normalize-space($codeblock/@outputclass), ' ')
                            [matches(., '^(language|lang)-.+')]
                            ! replace(lower-case(replace(., '^(language|lang)-', '')), '[^a-z0-9+#_.\-]', '')
                            [. ne ''])[1]"/>
  </xsl:function>

  <xsl:template match="*[contains(@class, ' pr-d/codeblock ')][exists(ci:codeblock-language(.))]" priority="10">
    <xsl:variable name="language" select="ci:codeblock-language(.)"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="spec-title-nospace"/>
    <pre data-language="{$language}">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setscale"/>
      <xsl:call-template name="setidaname"/>
      <code class="language-{$language}">
        <xsl:apply-templates/>
      </code>
    </pre>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <!-- Embedded token colours, only on pages that need them -->
  <xsl:template match="/ | node()" mode="gen-user-head" priority="5">
    <xsl:next-match/>
    <xsl:if test="$codeinclude.html.css = 'inline'
                  and exists(root(.)//*[contains(@class, ' pr-d/codeblock ')]
                                      //*[contains(@class, ' topic/ph ')][starts-with(@outputclass, 'hl-')])">
      <style type="text/css" data-source="org.dita-community.codeinclude">
        <xsl:value-of select="$ci:css"/>
      </style>
    </xsl:if>
  </xsl:template>

  <xsl:variable name="ci:css" as="xs:string"><![CDATA[
pre[data-language] .hl-comment { color: #6e7781; font-style: italic; }
pre[data-language] .hl-keyword { color: #cf222e; }
pre[data-language] .hl-key { color: #116329; }
pre[data-language] .hl-string, pre[data-language] .hl-cdata { color: #0a3069; }
pre[data-language] .hl-number, pre[data-language] .hl-literal { color: #0550ae; }
pre[data-language] .hl-type { color: #953800; }
pre[data-language] .hl-variable { color: #953800; }
pre[data-language] .hl-meta { color: #8250df; }
pre[data-language] .hl-tag { color: #116329; }
pre[data-language] .hl-attr, pre[data-language] .hl-option, pre[data-language] .hl-entity { color: #0550ae; }
pre[data-language] .hl-section { color: #8250df; font-weight: bold; }
pre[data-language] .hl-punct { color: #57606a; }
pre[data-language] .hl-inserted { color: #116329; background-color: #e6ffec; }
pre[data-language] .hl-deleted { color: #82071e; background-color: #ffebe9; }
]]></xsl:variable>

</xsl:stylesheet>
