<?xml version="1.0" encoding="UTF-8"?>
<!--
  Access policy for org.dita-community.codeinclude.

  A coderef makes the build read a file or URL and publish its contents.
  Whoever can edit a topic can therefore try to publish files from the
  build machine (keys, .env files, CI secrets) or make the build call
  internal services. These checks decide what a coderef may read:

  Local files
    * must resolve inside codeinclude.local.root (default: the directory of
      the input map), after ".." segments are normalised
    * encoded dots, slashes, backslashes and NUL (%2e %2f %5c %00) are
      refused, so the normalised path is the path that gets opened
    * only relative paths and file: URIs; jar:, ftp:, data: and every other
      scheme are refused, as are "//host", "\\host" and "file://host/"
      network paths

  Remote files
    * https only, unless codeinclude.remote.allow-http=yes
    * the host must be listed in codeinclude.remote.allow-hosts
      (default: the big public code hosts); "*" allows any public host
    * IP literals, localhost, single-label names and .local/.internal/
      .localhost names are always refused, even with "*"
    * no user:password@ in the URL and no non-default port
    * codeinclude.remote.require-pinned=warn|yes flags or refuses URLs that
      point at a branch instead of a commit hash

  Every result is also capped at codeinclude.max-size characters.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ci="urn:dita-community:codeinclude"
                exclude-result-prefixes="#all">

  <xsl:param name="local-root" as="xs:string" select="''"/>
  <xsl:param name="input" as="xs:string" select="''"/>
  <xsl:param name="input-dir" as="xs:string" select="''"/>
  <!-- Directory a relative codeinclude.local.root is resolved against: where dita was started -->
  <xsl:param name="cwd" as="xs:string" select="''"/>
  <xsl:param name="allow-hosts" as="xs:string"
             select="'github.com raw.githubusercontent.com gitlab.com bitbucket.org codeberg.org'"/>
  <xsl:param name="allow-http" as="xs:string" select="'no'"/>
  <xsl:param name="require-pinned" as="xs:string" select="'warn'"/>
  <xsl:param name="max-size" as="xs:string" select="'1048576'"/>

  <xsl:variable name="ci:max-size" as="xs:integer"
                select="if ($max-size castable as xs:integer) then xs:integer($max-size) else 1048576"/>

  <xsl:variable name="ci:allowed-hosts" as="xs:string*"
                select="tokenize(lower-case(normalize-space(translate($allow-hosts, ',;', '  '))), ' ')"/>

  <!-- Directory local files must stay inside, as a file: URI ending in "/", or '*' for no limit -->
  <xsl:variable name="ci:root" as="xs:string">
    <xsl:variable name="explicit" select="normalize-space($local-root)"/>
    <xsl:choose>
      <xsl:when test="$explicit = '*'">*</xsl:when>
      <xsl:when test="$explicit ne '' and ci:is-absolute($explicit)">
        <xsl:sequence select="ci:as-directory(ci:to-uri($explicit))"/>
      </xsl:when>
      <xsl:when test="$explicit ne '' and normalize-space($cwd) ne ''">
        <xsl:sequence select="ci:as-directory(string(resolve-uri($explicit, ci:as-directory(ci:to-uri(normalize-space($cwd))))))"/>
      </xsl:when>
      <xsl:when test="$explicit ne ''">
        <!-- Relative root with nothing to resolve it against: read no local files -->
        <xsl:sequence select="''"/>
      </xsl:when>
      <xsl:when test="normalize-space($input-dir) ne ''">
        <xsl:sequence select="ci:as-directory(ci:to-uri(normalize-space($input-dir)))"/>
      </xsl:when>
      <xsl:when test="normalize-space($input) ne ''">
        <xsl:sequence select="string(resolve-uri('.', ci:to-uri(normalize-space($input))))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:function name="ci:is-absolute" as="xs:boolean">
    <xsl:param name="path" as="xs:string"/>
    <xsl:sequence select="starts-with($path, '/') or matches($path, '^[A-Za-z]:[\\/]') or matches($path, '^file:', 'i')"/>
  </xsl:function>

  <xsl:function name="ci:as-directory" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:sequence select="if (ends-with($uri, '/')) then $uri else $uri || '/'"/>
  </xsl:function>

  <!-- Decode %XX escapes of printable ASCII so both sides of a path comparison use the same spelling -->
  <xsl:function name="ci:ascii-decode" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="string-join(analyze-string($s, '%[2-7][0-9A-Fa-f]')/*
                            ! (if (self::*:match)
                               then codepoints-to-string(
                                      (string-to-codepoints(upper-case(substring(., 2, 1))) - 48) * 16
                                      + (let $c := string-to-codepoints(upper-case(substring(., 3, 1)))
                                         return if ($c ge 65) then $c - 55 else $c - 48))
                               else string(.)))"/>
  </xsl:function>

  <!-- ===================================================================
       Checks on the href as written
       =================================================================== -->

  <!-- Reason the href is refused outright, or the empty sequence -->
  <xsl:function name="ci:href-problem" as="xs:string?">
    <xsl:param name="path" as="xs:string"/>
    <xsl:sequence select="
      if (matches($path, '[\p{Cc}]')) then 'it contains control characters'
      else if (matches($path, '%(2[eEfF]|5[cC]|00)')) then 'it contains an encoded dot, slash, backslash or NUL'
      else if (contains($path, '\')) then 'it contains a backslash'
      else if (starts-with($path, '//')) then 'network paths (//host/...) are not allowed'
      else if (matches($path, '^file://[^/]', 'i')) then 'network paths (file://host/...) are not allowed'
      else if (matches($path, '^[A-Za-z][A-Za-z0-9+.\-]*:')
               and not(matches($path, '^(https?|file):', 'i')))
        then 'only https, http and file references are allowed'
      else ()"/>
  </xsl:function>

  <!-- ===================================================================
       Local files
       =================================================================== -->

  <xsl:function name="ci:inside-root" as="xs:boolean">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$ci:root = '*'">
        <xsl:sequence select="matches($uri, '^file:', 'i')"/>
      </xsl:when>
      <xsl:when test="$ci:root = ''">
        <xsl:sequence select="false()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="target" select="ci:ascii-decode(ci:path-of($uri))"/>
        <xsl:variable name="root" select="ci:ascii-decode(ci:path-of($ci:root))"/>
        <xsl:sequence select="matches($uri, '^file:', 'i')
                              and not(matches($target, '(^|/)\.\.?(/|$)'))
                              and starts-with($target, $root)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===================================================================
       Remote files
       =================================================================== -->

  <xsl:variable name="ci:url-pattern" as="xs:string"
                select="'^([A-Za-z]+)://([^/?#]*)([/?#].*)?$'"/>

  <xsl:function name="ci:url-host" as="xs:string">
    <xsl:param name="url" as="xs:string"/>
    <xsl:sequence select="if (matches($url, $ci:url-pattern))
                          then lower-case(replace(replace(replace($url, $ci:url-pattern, '$2'), ':[0-9]*$', ''), '\.$', ''))
                          else ''"/>
  </xsl:function>

  <!-- Reason a remote URL is refused, or the empty sequence -->
  <xsl:function name="ci:remote-problem" as="xs:string?">
    <xsl:param name="url" as="xs:string"/>
    <xsl:variable name="ok-syntax" select="matches($url, $ci:url-pattern)"/>
    <xsl:variable name="scheme" select="if ($ok-syntax) then lower-case(replace($url, $ci:url-pattern, '$1')) else ''"/>
    <xsl:variable name="authority" select="if ($ok-syntax) then replace($url, $ci:url-pattern, '$2') else ''"/>
    <xsl:variable name="host" select="ci:url-host($url)"/>
    <xsl:variable name="port" select="if (matches($authority, ':[0-9]*$')) then replace($authority, '^.*:', '') else ''"/>
    <xsl:sequence select="
      if (not($ok-syntax)) then 'the URL could not be parsed'
      else if (not($scheme = ('https', 'http'))) then 'only https and http URLs can be fetched'
      else if ($scheme = 'http' and not(lower-case($allow-http) = $ci:yes))
        then 'plain http is refused; use https or set codeinclude.remote.allow-http=yes'
      else if (contains($authority, '@')) then 'URLs with user names or passwords are refused'
      else if ($port ne '' and not(($scheme = 'https' and $port = '443') or ($scheme = 'http' and $port = '80')))
        then 'non-default ports are refused'
      else if (starts-with($host, '[') or matches($host, '^[0-9.]+$') or matches($host, '^0x', 'i'))
        then 'IP address hosts are refused'
      else if (not(contains($host, '.')) or matches($host, '\.(local|localhost|internal|lan|home|corp|intranet)\.?$')
               or $host = ('localhost', 'metadata.google.internal'))
        then 'local and internal host names are refused'
      else if (not($ci:allowed-hosts = ('*', $host)))
        then 'host ' || $host || ' is not in codeinclude.remote.allow-hosts'
      else if (lower-case($require-pinned) = $ci:yes and not(ci:is-pinned($url)))
        then 'the URL is not pinned to a commit hash (codeinclude.remote.require-pinned=yes)'
      else ()"/>
  </xsl:function>

  <!-- Does the URL name a commit (40 or 64 hex digits) rather than a branch or tag? -->
  <xsl:function name="ci:is-pinned" as="xs:boolean">
    <xsl:param name="url" as="xs:string"/>
    <xsl:sequence select="matches(replace($url, '[?#].*$', ''), '/([0-9a-fA-F]{40}|[0-9a-fA-F]{64})(/|$)')"/>
  </xsl:function>

</xsl:stylesheet>
