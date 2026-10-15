<?xml version="1.0" encoding="UTF-8"?>
<!--
  Build-time syntax highlighter for org.dita-community.codeinclude.

  ci:highlight($text, $language) returns a sequence of text nodes and
  <ph class="- topic/ph " outputclass="hl-*"> elements. Being plain DITA,
  the result renders in any output format; the HTML5 and PDF overrides in
  this plugin add colours.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:ci="urn:dita-community:codeinclude"
                exclude-result-prefixes="#all">

  <xsl:include href="languages.xsl"/>

  <!-- Can this language be highlighted? -->
  <xsl:function name="ci:highlightable" as="xs:boolean">
    <xsl:param name="language" as="xs:string"/>
    <xsl:sequence select="$language = ('yaml', 'html') or map:contains($ci:spec, $language)"/>
  </xsl:function>

  <xsl:function name="ci:highlight" as="node()*">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="language" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$language = 'yaml'">
        <xsl:sequence select="ci:yaml($text)"/>
      </xsl:when>
      <xsl:when test="$language = 'html'">
        <xsl:sequence select="ci:run($text, $ci:spec('xml'), 'xml')"/>
      </xsl:when>
      <xsl:when test="map:contains($ci:spec, $language)">
        <xsl:sequence select="ci:run($text, $ci:spec($language), $language)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===================================================================
       Generic regex-driven tokenizer
       =================================================================== -->

  <xsl:function name="ci:run" as="node()*">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="spec" as="map(*)*"/>
    <xsl:param name="language" as="xs:string"/>
    <xsl:variable name="regex" select="string-join($spec ! ('(' || ?re || ')'), '|')"/>
    <xsl:variable name="count" select="count($spec)"/>
    <xsl:analyze-string select="$text" regex="{$regex}" flags="m">
      <xsl:matching-substring>
        <xsl:variable name="groups" as="xs:string*"
                      select="for $i in 1 to $count return regex-group($i)"/>
        <xsl:variable name="index" select="(for $i in 1 to $count return $i[$groups[$i] ne ''])[1]"/>
        <xsl:sequence select="ci:emit($spec[$index]?class, ., $language)"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <!-- One token element -->
  <xsl:function name="ci:tok" as="node()*">
    <xsl:param name="class" as="xs:string"/>
    <xsl:param name="text" as="xs:string"/>
    <xsl:if test="$text ne ''">
      <ph class="- topic/ph " outputclass="hl-{$class}">
        <xsl:value-of select="$text"/>
      </ph>
    </xsl:if>
  </xsl:function>

  <!-- Turn a matched token into output, applying per-class post-processing -->
  <xsl:function name="ci:emit" as="node()*">
    <xsl:param name="class" as="xs:string"/>
    <xsl:param name="token" as="xs:string"/>
    <xsl:param name="language" as="xs:string"/>
    <!-- Some patterns consume leading blanks to stand in for a look-behind; keep those blanks unstyled -->
    <xsl:variable name="lead" select="ci:leading-blanks($token)"/>
    <xsl:variable name="body" select="substring($token, string-length($lead) + 1)"/>
    <xsl:if test="$lead ne ''">
      <xsl:value-of select="$lead"/>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$class = 'ident'">
        <xsl:variable name="ci" select="$language = $ci:case-insensitive"/>
        <xsl:variable name="probe" select="if ($ci) then upper-case($body) else $body"/>
        <xsl:variable name="keywords" select="for $k in $ci:keywords($language) return (if ($ci) then upper-case($k) else $k)"/>
        <xsl:variable name="literals"
                      select="(if (map:contains($ci:literals, $language)) then $ci:literals($language) else $ci:literals('*'))
                              ! (if ($ci) then upper-case(.) else .)"/>
        <xsl:choose>
          <xsl:when test="$probe = $keywords">
            <xsl:sequence select="ci:tok('keyword', $body)"/>
          </xsl:when>
          <xsl:when test="$probe = $literals">
            <xsl:sequence select="ci:tok('literal', $body)"/>
          </xsl:when>
          <xsl:when test="matches($body, '^[A-Z][A-Za-z0-9]*[a-z][A-Za-z0-9]*$')
                          and not($language = ('bash', 'dockerfile', 'make', 'ini', 'properties', 'toml', 'sql'))">
            <xsl:sequence select="ci:tok('type', $body)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$body"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$class = 'json-key'">
        <xsl:analyze-string select="$body" regex="^(.*?)(\s*:)$" flags="s">
          <xsl:matching-substring>
            <xsl:sequence select="ci:tok('key', regex-group(1)), ci:tok('punct', regex-group(2))"/>
          </xsl:matching-substring>
        </xsl:analyze-string>
      </xsl:when>
      <xsl:when test="$class = 'ini-key'">
        <xsl:analyze-string select="$body" regex="^(.*?[^ \t=])([ \t]*=?)$" flags="s">
          <xsl:matching-substring>
            <xsl:sequence select="ci:tok('key', regex-group(1))"/>
            <xsl:value-of select="replace(regex-group(2), '=', '')"/>
            <xsl:sequence select="ci:tok('punct', replace(regex-group(2), '[^=]', ''))"/>
          </xsl:matching-substring>
        </xsl:analyze-string>
      </xsl:when>
      <xsl:when test="$class = 'xml-tag'">
        <xsl:sequence select="ci:xml-tag($body)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="ci:tok($class, $body)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===================================================================
       XML / HTML tags
       =================================================================== -->

  <xsl:function name="ci:xml-tag" as="node()*">
    <xsl:param name="tag" as="xs:string"/>
    <xsl:analyze-string select="$tag" regex="^(&lt;/?)([^\s/&gt;]+)([\s\S]*?)(/?&gt;)$">
      <xsl:matching-substring>
        <xsl:sequence select="ci:tok('punct', regex-group(1)), ci:tok('tag', regex-group(2))"/>
        <xsl:analyze-string select="regex-group(3)"
                            regex="([^\s=&quot;']+)(\s*=\s*)(&quot;[^&quot;]*&quot;|'[^']*')|([^\s=&quot;']+)">
          <xsl:matching-substring>
            <xsl:choose>
              <xsl:when test="regex-group(1) ne ''">
                <xsl:sequence select="ci:tok('attr', regex-group(1)),
                                      ci:tok('punct', regex-group(2)),
                                      ci:tok('string', regex-group(3))"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="ci:tok('attr', regex-group(4))"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:value-of select="."/>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
        <xsl:sequence select="ci:tok('punct', regex-group(4))"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <!-- ===================================================================
       YAML (line oriented, tracks block scalars)
       =================================================================== -->

  <xsl:variable name="ci:yaml-value-spec" as="map(*)*" select="(
      ci:t('comment', '(?:^|[ \t])#[^\n]*'),
      ci:t('string', $ci:re-dq),
      ci:t('string', '''(?:[^'']|'''')*'''),
      ci:t('variable', '[&amp;*][^\s,\[\]{}]+'),
      ci:t('meta', '![^\s,\[\]{}]*'),
      ci:t('punct', '[\[\]{},]'),
      ci:t('scalar', '[^\s,\[\]{}#][^\s,\[\]{}]*'))"/>

  <!-- key: value line -->
  <xsl:variable name="ci:yaml-key-line" as="xs:string"
                select="'^([ \t]*)((?:-[ \t]+)*)(&quot;(?:[^&quot;\\]|\\.)*&quot;|''(?:[^'']|'''')*''|[^\s#&quot;''\-\[\]{},&amp;*!|&gt;%@`?][^#\n]*?|-[^\s#][^#\n]*?|\?[ \t][^#\n]*?)([ \t]*)(:)((?:[ \t].*)?)$'"/>
  <!-- list item without a key -->
  <xsl:variable name="ci:yaml-item-line" as="xs:string" select="'^([ \t]*)((?:-(?:[ \t]+|$))+)(.*)$'"/>

  <!-- Leading spaces and tabs of a string (replace() cannot be used: the pattern would match "") -->
  <xsl:function name="ci:leading-blanks" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="(analyze-string($s, '^[ \t]+')/*:match/string(), '')[1]"/>
  </xsl:function>

  <xsl:function name="ci:indent" as="xs:integer">
    <xsl:param name="line" as="xs:string"/>
    <xsl:sequence select="string-length(ci:leading-blanks($line))"/>
  </xsl:function>

  <!-- Does a value open a block scalar (| or >, with optional indicators)? -->
  <xsl:function name="ci:yaml-block-start" as="xs:boolean">
    <xsl:param name="value" as="xs:string"/>
    <xsl:sequence select="matches($value, '^[ \t]*(?:![^\s]*[ \t]+)?(?:&amp;[^\s]+[ \t]+)?[|&gt;][+\-0-9]*[ \t]*(?:#.*)?$')"/>
  </xsl:function>

  <xsl:function name="ci:yaml" as="node()*">
    <xsl:param name="text" as="xs:string"/>
    <xsl:variable name="lines" select="tokenize($text, '\n')"/>
    <xsl:iterate select="$lines">
      <!-- indentation of the key that opened the current block scalar, or -1 -->
      <xsl:param name="block" as="xs:integer" select="-1"/>
      <xsl:if test="position() gt 1">
        <xsl:text>&#10;</xsl:text>
      </xsl:if>
      <xsl:variable name="line" select="."/>
      <xsl:variable name="in-block" select="$block ge 0 and (normalize-space($line) = '' or ci:indent($line) gt $block)"/>
      <xsl:choose>
        <xsl:when test="$in-block">
          <xsl:value-of select="ci:leading-blanks($line)"/>
          <xsl:sequence select="ci:tok('string', substring($line, string-length(ci:leading-blanks($line)) + 1))"/>
          <xsl:next-iteration>
            <xsl:with-param name="block" select="$block"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="matches($line, '^[ \t]*#')">
          <xsl:value-of select="ci:leading-blanks($line)"/>
          <xsl:sequence select="ci:tok('comment', substring($line, string-length(ci:leading-blanks($line)) + 1))"/>
          <xsl:next-iteration>
            <xsl:with-param name="block" select="-1"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="matches($line, '^(---|\.\.\.)(\s|$)') or matches($line, '^%')">
          <xsl:sequence select="ci:tok('meta', replace($line, '^(---|\.\.\.|%\S*).*$', '$1'))"/>
          <xsl:variable name="rest" select="replace($line, '^(---|\.\.\.|%\S*)', '')"/>
          <xsl:sequence select="ci:run($rest, $ci:yaml-value-spec, 'yaml') ! ci:yaml-scalars(.)"/>
          <xsl:next-iteration>
            <xsl:with-param name="block" select="-1"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="matches($line, $ci:yaml-key-line)">
          <xsl:variable name="indent" select="replace($line, $ci:yaml-key-line, '$1')"/>
          <xsl:variable name="dashes" select="replace($line, $ci:yaml-key-line, '$2')"/>
          <xsl:variable name="value" select="replace($line, $ci:yaml-key-line, '$6')"/>
          <xsl:value-of select="$indent"/>
          <xsl:sequence select="ci:yaml-dashes($dashes)"/>
          <xsl:sequence select="ci:tok('key', replace($line, $ci:yaml-key-line, '$3'))"/>
          <xsl:value-of select="replace($line, $ci:yaml-key-line, '$4')"/>
          <xsl:sequence select="ci:tok('punct', ':')"/>
          <xsl:sequence select="ci:yaml-value($value)"/>
          <xsl:next-iteration>
            <xsl:with-param name="block"
                            select="if (ci:yaml-block-start($value))
                                    then string-length($indent) + string-length($dashes)
                                    else -1"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="matches($line, $ci:yaml-item-line)">
          <xsl:variable name="indent" select="replace($line, $ci:yaml-item-line, '$1')"/>
          <xsl:variable name="dashes" select="replace($line, $ci:yaml-item-line, '$2')"/>
          <xsl:variable name="value" select="replace($line, $ci:yaml-item-line, '$3')"/>
          <xsl:value-of select="$indent"/>
          <xsl:sequence select="ci:yaml-dashes($dashes)"/>
          <xsl:sequence select="ci:yaml-value($value)"/>
          <xsl:next-iteration>
            <xsl:with-param name="block"
                            select="if (ci:yaml-block-start($value))
                                    then string-length($indent)
                                    else -1"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="ci:yaml-value($line)"/>
          <xsl:next-iteration>
            <xsl:with-param name="block" select="-1"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:function>

  <xsl:function name="ci:yaml-dashes" as="node()*">
    <xsl:param name="dashes" as="xs:string"/>
    <xsl:analyze-string select="$dashes" regex="-">
      <xsl:matching-substring>
        <xsl:sequence select="ci:tok('punct', '-')"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="ci:yaml-value" as="node()*">
    <xsl:param name="value" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="ci:yaml-block-start($value)">
        <xsl:analyze-string select="$value" regex="([|&gt;][+\-0-9]*)|((?:^|[ \t])#.*$)">
          <xsl:matching-substring>
            <xsl:sequence select="if (regex-group(1) ne '') then ci:tok('meta', .) else ci:emit('comment', ., 'yaml')"/>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:sequence select="ci:run(., $ci:yaml-value-spec, 'yaml') ! ci:yaml-scalars(.)"/>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="ci:run($value, $ci:yaml-value-spec, 'yaml') ! ci:yaml-scalars(.)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Re-classify plain scalars as number / literal / key / string -->
  <xsl:function name="ci:yaml-scalars" as="node()*">
    <xsl:param name="node" as="node()"/>
    <xsl:choose>
      <xsl:when test="$node/self::ph[@outputclass = 'hl-scalar']">
        <xsl:variable name="s" select="string($node)"/>
        <xsl:choose>
          <xsl:when test="matches($s, '^[\-+]?(?:[0-9][0-9_]*(?:\.[0-9_]*)?(?:[eE][\-+]?[0-9]+)?|\.[0-9]+|0x[0-9a-fA-F_]+|0o[0-7_]+|\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))$')">
            <xsl:sequence select="ci:tok('number', $s)"/>
          </xsl:when>
          <xsl:when test="$s = ('true', 'false', 'True', 'False', 'TRUE', 'FALSE', 'yes', 'no', 'Yes', 'No',
                                'on', 'off', 'On', 'Off', 'null', 'Null', 'NULL', '~')">
            <xsl:sequence select="ci:tok('literal', $s)"/>
          </xsl:when>
          <xsl:when test="matches($s, '^[^:]+:$')">
            <!-- key inside a flow mapping: {a: 1} -->
            <xsl:sequence select="ci:tok('key', substring($s, 1, string-length($s) - 1)), ci:tok('punct', ':')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="ci:tok('string', $s)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$node"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
