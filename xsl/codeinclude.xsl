<?xml version="1.0" encoding="UTF-8"?>
<!--
  Preprocessing step for org.dita-community.codeinclude.

  Runs on every temporary topic after preprocessing. For each codeblock it

  1. replaces every <coderef href="..."/> with the referenced text. The href
     may be a relative path, an absolute file URI, or an http(s) URL.
     GitHub, GitLab, Bitbucket and Gitea/Codeberg "blob" page URLs are
     rewritten to their raw-file equivalents. Fragments select lines:
       #L10-L20, #L10            (GitHub style, 1-based)
       #line-range(10,20)        (DITA-OT style, 1-based)
       #line=9,20                (RFC 5147, 0-based positions)
       #token=start,end          (DITA-OT anchor style)
  2. works out the language from @outputclass (language-x, lang-x or a bare
     language name), coderef/@format, or the file name, and adds
     outputclass="language-x" so downstream tools can see it.
  3. replaces the text with highlighted <ph outputclass="hl-*"> tokens.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:err="http://www.w3.org/2005/xqt-errors"
                xmlns:ci="urn:dita-community:codeinclude"
                exclude-result-prefixes="#all">

  <xsl:include href="highlight.xsl"/>
  <xsl:include href="security.xsl"/>

  <xsl:param name="job-url" as="xs:string" select="''"/>
  <xsl:param name="temp-dir-url" as="xs:string" select="''"/>
  <xsl:param name="remote" as="xs:string" select="'yes'"/>
  <xsl:param name="highlight" as="xs:string" select="'yes'"/>
  <xsl:param name="default-language" as="xs:string" select="''"/>
  <xsl:param name="default-charset" as="xs:string" select="'UTF-8'"/>
  <xsl:param name="fail-on-error" as="xs:string" select="'no'"/>
  <xsl:param name="processing-mode" as="xs:string" select="'lax'"/>
  <!-- Skip highlighting (but still include) beyond these sizes, to bound regex work on hostile input -->
  <xsl:param name="highlight-max-size" as="xs:string" select="'262144'"/>
  <xsl:param name="highlight-max-line" as="xs:string" select="'4000'"/>

  <xsl:variable name="ci:yes" select="('yes', 'true', '1', 'on')"/>
  <xsl:variable name="ci:fatal" select="lower-case($fail-on-error) = $ci:yes or $processing-mode = 'strict'"/>

  <xsl:variable name="ci:job" as="document-node()?"
                select="if ($job-url ne '' and doc-available($job-url)) then doc($job-url) else ()"/>

  <xsl:key name="ci:job-file" match="file" use="@uri"/>

  <xsl:mode on-no-match="shallow-copy"/>

  <!-- ===================================================================
       Codeblock
       =================================================================== -->

  <xsl:template match="*[contains(@class, ' pr-d/codeblock ')]">
    <xsl:variable name="codeblock" select="."/>
    <xsl:variable name="classes" select="tokenize(normalize-space(@outputclass), ' ')"/>
    <xsl:variable name="declared" select="ci:language-from-outputclass($classes)"/>
    <xsl:variable name="language" select="($declared, ci:language-from-coderefs(.), ci:canonical-language($default-language), '')[. ne ''][1]"/>
    <xsl:variable name="coderefs" select="*[contains(@class, ' pr-d/coderef ')]"/>

    <xsl:variable name="is-flag" select="function($n as node()) as xs:boolean {
        exists($n/self::*[contains(@class, ' ditaot-d/ditaval-startprop ') or contains(@class, ' ditaot-d/ditaval-endprop ')]) }"/>

    <!-- With a coderef, whitespace used to pretty-print the markup around it is not part of the code -->
    <xsl:variable name="significant" select="node()[not(self::text()[normalize-space() = ''])][not($is-flag(.))]"/>
    <xsl:variable name="children"
                  select="if (empty($coderefs)) then node()
                          else node()[not(self::text()[normalize-space() = '']
                                          and (empty($significant) or . &lt;&lt; $significant[1] or . &gt;&gt; $significant[last()]))]"/>

    <xsl:variable name="start-flags" select="$children[$is-flag(.)][contains(@class, ' ditaot-d/ditaval-startprop ')]"/>
    <xsl:variable name="end-flags" select="$children[$is-flag(.)][contains(@class, ' ditaot-d/ditaval-endprop ')]"/>
    <xsl:variable name="body" as="node()*">
      <xsl:apply-templates select="$children[not($is-flag(.))]" mode="ci:resolve"/>
    </xsl:variable>
    <xsl:variable name="text-only" select="every $n in $body satisfies $n instance of text()"/>

    <xsl:copy>
      <xsl:apply-templates select="@* except @outputclass"/>
      <xsl:variable name="new-classes"
                    select="$classes, ('language-' || $language)[$language ne '' and not($declared)]"/>
      <xsl:if test="exists($new-classes)">
        <xsl:attribute name="outputclass" select="string-join($new-classes, ' ')"/>
      </xsl:if>
      <xsl:apply-templates select="$start-flags"/>
      <xsl:choose>
        <xsl:when test="$text-only and exists($body)">
          <xsl:variable name="joined" select="string-join($body)"/>
          <xsl:variable name="code" select="if (exists($coderefs) and $classes = 'normalize-space')
                                            then ci:strip-common-indent($joined) else $joined"/>
          <xsl:choose>
            <xsl:when test="lower-case($highlight) = $ci:yes and $language ne '' and ci:highlightable($language)
                            and ci:small-enough($code)">
              <xsl:sequence select="ci:highlight($code, $language)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$code"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$body"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="$end-flags"/>
    </xsl:copy>
  </xsl:template>

  <!-- Codeblock children: copy, but resolve coderef -->
  <xsl:template match="node()" mode="ci:resolve">
    <xsl:apply-templates select="." mode="#default"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' pr-d/coderef ')]" mode="ci:resolve">
    <xsl:variable name="href" select="normalize-space(@href)"/>
    <xsl:variable name="fragment" select="if (contains($href, '#')) then substring-after($href, '#') else ''"/>
    <xsl:variable name="path" select="if (contains($href, '#')) then substring-before($href, '#') else $href"/>
    <xsl:variable name="charset" select="ci:charset(@format)"/>
    <xsl:variable name="is-remote" select="ci:is-remote($path)"/>
    <xsl:variable name="url" select="if ($is-remote) then ci:raw-url($path) else ''"/>
    <xsl:variable name="problem" as="xs:string?"
                  select="if ($href = '') then 'coderef has no href'
                          else (ci:href-problem($path),
                                if ($is-remote and not(lower-case($remote) = $ci:yes)) then 'remote references are off (codeinclude.remote=no)' else (),
                                if ($is-remote) then ci:remote-problem($url) else ())[1]"/>
    <!-- Local: only candidates inside the allowed root are ever opened -->
    <xsl:variable name="candidates" select="if ($is-remote or exists($problem)) then () else ci:candidates(., $path)"/>
    <xsl:variable name="allowed" select="$candidates[ci:inside-root(.)]"/>
    <xsl:choose>
      <xsl:when test="exists($problem)">
        <xsl:call-template name="ci:refuse">
          <xsl:with-param name="text" select="'Code reference ' || $href || ' was not included: ' || $problem"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="not($is-remote) and empty($allowed)">
        <xsl:call-template name="ci:refuse">
          <xsl:with-param name="text" select="'Code reference ' || $href || ' was not included: it resolves to '
                                              || ($candidates[1], '?')[1] || ', outside codeinclude.local.root ('
                                              || ($ci:root[. ne ''], 'not set')[1] || ')'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="$is-remote and lower-case($require-pinned) = 'warn' and not(ci:is-pinned($url))">
          <xsl:call-template name="ci:report">
            <xsl:with-param name="id" select="'CINC006W'"/>
            <xsl:with-param name="level" select="'WARN'"/>
            <xsl:with-param name="text" select="'Remote code reference follows a branch or tag, so its content can change without your sources changing. Pin it to a commit hash: ' || $href"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:variable name="target" select="if ($is-remote) then $url
                                            else ($allowed[unparsed-text-available(., $charset)], $allowed[1])[1]"/>
        <xsl:try>
          <xsl:variable name="raw" select="unparsed-text($target, $charset)"/>
          <xsl:choose>
            <xsl:when test="string-length($raw) gt $ci:max-size">
              <xsl:call-template name="ci:refuse">
                <xsl:with-param name="text" select="'Code reference ' || $href || ' was not included: '
                                                    || string-length($raw) || ' characters is over codeinclude.max-size ('
                                                    || $ci:max-size || ')'"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="ci:select-lines(ci:normalize-newlines($raw), $fragment)"/>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:catch>
            <xsl:call-template name="ci:refuse">
              <xsl:with-param name="id" select="'CINC001'"/>
              <xsl:with-param name="text" select="'Unable to read code reference ' || $href || ' (' || $target
                                                  || ', charset ' || $charset || '): ' || $err:description"/>
            </xsl:call-template>
          </xsl:catch>
        </xsl:try>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Report a coderef that was not included; stops the build in strict mode -->
  <xsl:template name="ci:refuse">
    <xsl:param name="id" as="xs:string" select="'CINC005'"/>
    <xsl:param name="text" as="xs:string"/>
    <xsl:call-template name="ci:report">
      <xsl:with-param name="id" select="$id || (if ($ci:fatal) then 'E' else 'W')"/>
      <xsl:with-param name="level" select="if ($ci:fatal) then 'ERROR' else 'WARN'"/>
      <xsl:with-param name="text" select="$text"/>
    </xsl:call-template>
    <xsl:if test="$ci:fatal">
      <xsl:message terminate="yes">[CINC002F][FATAL]: Stopping because codeinclude.fail-on-error=yes or processing-mode=strict</xsl:message>
    </xsl:if>
  </xsl:template>

  <xsl:function name="ci:small-enough" as="xs:boolean">
    <xsl:param name="code" as="xs:string"/>
    <xsl:variable name="max-size" select="if ($highlight-max-size castable as xs:integer) then xs:integer($highlight-max-size) else 262144"/>
    <xsl:variable name="max-line" select="if ($highlight-max-line castable as xs:integer) then xs:integer($highlight-max-line) else 4000"/>
    <xsl:sequence select="string-length($code) le $max-size
                          and max((tokenize($code, '\n') ! string-length(.), 0)) le $max-line"/>
  </xsl:function>

  <!-- ===================================================================
       Language detection
       =================================================================== -->

  <xsl:function name="ci:language-from-outputclass" as="xs:string?">
    <xsl:param name="classes" as="xs:string*"/>
    <xsl:sequence select="(for $c in $classes return
                             if (matches($c, '^(language|lang)-.+'))
                             then (ci:canonical-language(replace($c, '^(language|lang)-', ''))[. ne ''],
                                   ci:safe-name(replace($c, '^(language|lang)-', ''))[. ne ''])[1]
                             else ci:canonical-language($c)[. ne ''])[1]"/>
  </xsl:function>

  <!-- Language names end up in class and data- attributes: keep them to a safe alphabet -->
  <xsl:function name="ci:safe-name" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="substring(replace(lower-case($s), '[^a-z0-9+#_.\-]', ''), 1, 32)"/>
  </xsl:function>

  <xsl:function name="ci:language-from-coderefs" as="xs:string?">
    <xsl:param name="codeblock" as="element()"/>
    <xsl:variable name="ref" select="$codeblock/*[contains(@class, ' pr-d/coderef ')][1]"/>
    <xsl:variable name="format" select="ci:canonical-language(tokenize(string($ref/@format), ';')[1])"/>
    <xsl:sequence select="if ($format ne '' and $format ne 'text') then $format
                          else if (exists($ref)) then ci:language-from-path($ref/@href)[. ne '']
                          else ()"/>
  </xsl:function>

  <!-- ===================================================================
       Locating and reading the file
       =================================================================== -->

  <xsl:function name="ci:is-remote" as="xs:boolean">
    <xsl:param name="href" as="xs:string"/>
    <xsl:sequence select="matches($href, '^https?://', 'i')"/>
  </xsl:function>

  <!-- Rewrite web "view file" links to raw-file links -->
  <xsl:function name="ci:raw-url" as="xs:string">
    <xsl:param name="url" as="xs:string"/>
    <xsl:sequence select="
      if (matches($url, '^https?://(www\.)?github\.com/[^/]+/[^/]+/(blob|raw)/', 'i'))
        then replace(replace($url, '^https?://(www\.)?github\.com/([^/]+)/([^/]+)/(blob|raw)/', 'https://raw.githubusercontent.com/$2/$3/', 'i'),
                     '[?&amp;]plain=1', '')
      else if (contains($url, '/-/blob/')) then replace($url, '/-/blob/', '/-/raw/')
      else if (matches($url, '^https?://bitbucket\.org/[^/]+/[^/]+/src/', 'i'))
        then replace($url, '^(https?://bitbucket\.org/[^/]+/[^/]+)/src/', '$1/raw/', 'i')
      else if (matches($url, '/src/(branch|tag|commit)/'))
        then replace($url, '/src/(branch|tag|commit)/', '/raw/$1/')
      else $url"/>
  </xsl:function>

  <!-- Absolute URIs to try, best first -->
  <xsl:function name="ci:candidates" as="xs:string*">
    <xsl:param name="coderef" as="element()"/>
    <xsl:param name="path" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="ci:is-remote($path)">
        <xsl:sequence select="ci:raw-url($path)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="temp-target" select="string(resolve-uri($path, base-uri($coderef)))"/>
        <!-- 1. the job: temp location of the code file -> original source -->
        <xsl:variable name="from-job" as="xs:string*">
          <xsl:if test="exists($ci:job) and $temp-dir-url ne ''">
            <xsl:variable name="rel" select="ci:relative-to(ci:path-of($temp-target), ci:path-of($temp-dir-url))"/>
            <xsl:sequence select="(key('ci:job-file', $rel, $ci:job), key('ci:job-file', ci:decode($rel), $ci:job))[@src][1]/@src/string()"/>
          </xsl:if>
        </xsl:variable>
        <!-- 2. the source file the coderef came from (debug attribute) -->
        <xsl:variable name="xtrf" select="$coderef/ancestor-or-self::*[@xtrf][1]/@xtrf"/>
        <xsl:variable name="from-xtrf" select="if (exists($xtrf)) then string(resolve-uri($path, ci:to-uri($xtrf))) else ()"/>
        <xsl:sequence select="distinct-values(($from-job, $from-xtrf, $temp-target))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="ci:to-uri" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="
      if (matches($s, '^[A-Za-z]:[\\/]')) then 'file:/' || translate($s, '\', '/')
      else if (matches($s, '^[A-Za-z][A-Za-z0-9+.\-]+:')) then $s
      else if (starts-with($s, '/')) then 'file:' || $s
      else $s"/>
  </xsl:function>

  <!-- file:/a/b, file:///a/b and /a/b all become /a/b -->
  <xsl:function name="ci:path-of" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:variable name="p" select="replace($uri, '^file:/+', '/', 'i')"/>
    <xsl:sequence select="$p"/>
  </xsl:function>

  <xsl:function name="ci:relative-to" as="xs:string">
    <xsl:param name="path" as="xs:string"/>
    <xsl:param name="dir" as="xs:string"/>
    <xsl:variable name="d" select="if (ends-with($dir, '/')) then $dir else $dir || '/'"/>
    <xsl:sequence select="if (starts-with($path, $d)) then substring-after($path, $d) else $path"/>
  </xsl:function>

  <xsl:function name="ci:decode" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="replace(replace(replace($s, '%20', ' '), '%23', '#'), '%25', '%')"/>
  </xsl:function>

  <xsl:function name="ci:charset" as="xs:string">
    <xsl:param name="format" as="attribute()?"/>
    <xsl:variable name="m" select="analyze-string(string($format), 'charset\s*=\s*([^;\s]+)', 'i')//*:group[@nr = 1]"/>
    <xsl:sequence select="(string($m[1])[matches(., '^[A-Za-z0-9][A-Za-z0-9._:\-]{0,39}$')], $default-charset[. ne ''], 'UTF-8')[1]"/>
  </xsl:function>

  <xsl:function name="ci:normalize-newlines" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="replace(replace($s, '\r\n?', '&#10;'), '^&#xFEFF;', '')"/>
  </xsl:function>

  <!-- ===================================================================
       Line selection
       =================================================================== -->

  <xsl:function name="ci:select-lines" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="fragment" as="xs:string"/>
    <xsl:variable name="all" select="tokenize($text, '\n')"/>
    <xsl:variable name="lines" select="if (ends-with($text, '&#10;')) then $all[position() lt last()] else $all"/>
    <xsl:variable name="f" select="normalize-space($fragment)"/>
    <xsl:variable name="selected" as="xs:string*">
      <xsl:choose>
        <xsl:when test="matches($f, '^L[0-9]+(C[0-9]+)?(-L?[0-9]+(C[0-9]+)?)?$')">
          <xsl:variable name="n" select="analyze-string($f, '[0-9]+')//*:match ! xs:integer(.)"/>
          <!-- L10C3-L20C5 yields 10 3 20 5; take the line numbers only -->
          <xsl:variable name="start" select="$n[1]"/>
          <xsl:variable name="end" select="if (contains($f, '-')) then (if (matches($f, '^L[0-9]+C')) then $n[3] else $n[2]) else $start"/>
          <xsl:sequence select="$lines[position() ge $start and position() le $end]"/>
        </xsl:when>
        <xsl:when test="matches($f, '^line-range\(\s*[0-9]+\s*(,\s*[0-9]+\s*)?\)$')">
          <xsl:variable name="n" select="analyze-string($f, '[0-9]+')//*:match ! xs:integer(.)"/>
          <xsl:sequence select="$lines[position() ge $n[1] and position() le ($n[2], count($lines))[1]]"/>
        </xsl:when>
        <xsl:when test="matches($f, '^line=[0-9]+$')">
          <xsl:sequence select="$lines[xs:integer(substring-after($f, '=')) + 1]"/>
        </xsl:when>
        <xsl:when test="matches($f, '^line=[0-9]*,[0-9]*$')">
          <xsl:variable name="a" select="substring-before(substring-after($f, '='), ',')"/>
          <xsl:variable name="b" select="substring-after($f, ',')"/>
          <xsl:variable name="start" select="if ($a = '') then 0 else xs:integer($a)"/>
          <xsl:variable name="end" select="if ($b = '') then count($lines) else xs:integer($b)"/>
          <xsl:sequence select="$lines[position() gt $start and position() le $end]"/>
        </xsl:when>
        <xsl:when test="matches($f, '^token=[^,\s)]*(,\s*[^,\s)]+)?$')">
          <xsl:variable name="spec" select="substring-after($f, '=')"/>
          <xsl:variable name="start" select="normalize-space(tokenize($spec, ',')[1])[. ne '']"/>
          <xsl:variable name="end" select="normalize-space(tokenize($spec, ',')[2])[. ne '']"/>
          <xsl:sequence select="ci:token-range($lines, $start, $end)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$lines"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="string-join($selected, '&#10;')"/>
  </xsl:function>

  <!-- Same semantics as DITA-OT's AnchorRange: lines strictly between the start and end anchors -->
  <xsl:function name="ci:token-range" as="xs:string*">
    <xsl:param name="lines" as="xs:string*"/>
    <xsl:param name="start" as="xs:string?"/>
    <xsl:param name="end" as="xs:string?"/>
    <xsl:iterate select="$lines">
      <xsl:param name="include" as="xs:integer" select="if (exists($start)) then -1 else 1"/>
      <xsl:variable name="state" as="xs:integer"
                    select="if ($include eq -1 and exists($start)) then (if (contains(., $start)) then 0 else -1)
                            else if ($include gt -1 and exists($end)) then (if (contains(., $end)) then -1 else $include)
                            else $include"/>
      <xsl:if test="$state gt 0">
        <xsl:sequence select="."/>
      </xsl:if>
      <xsl:next-iteration>
        <xsl:with-param name="include" select="if ($state ge 0) then $state + 1 else $state"/>
      </xsl:next-iteration>
    </xsl:iterate>
  </xsl:function>

  <!-- Remove the indentation shared by all non-empty lines (outputclass="normalize-space") -->
  <xsl:function name="ci:strip-common-indent" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:variable name="lines" select="tokenize($text, '\n')"/>
    <xsl:variable name="nonempty" select="$lines[normalize-space() ne '']"/>
    <xsl:variable name="min" select="if (empty($nonempty)) then 0 else min($nonempty ! string-length(ci:leading-blanks(.)))"/>
    <xsl:sequence select="if ($min gt 0) then string-join($lines ! substring(., $min + 1), '&#10;') else $text"/>
  </xsl:function>

  <!-- ===================================================================
       Messages in DITA-OT's [ID][LEVEL] format
       =================================================================== -->

  <xsl:template name="ci:report">
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="level" as="xs:string"/>
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="context" as="element()" select="."/>
    <xsl:variable name="where" select="string-join(($context/@xtrf, $context/@xtrc), ':')"/>
    <xsl:message select="'[' || $id || '][' || $level || ']: ' || $text || (if ($where ne '') then ' [' || $where || ']' else '')"/>
  </xsl:template>

</xsl:stylesheet>
