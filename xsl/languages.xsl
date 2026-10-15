<?xml version="1.0" encoding="UTF-8"?>
<!--
  Language registry for org.dita-community.codeinclude.

  Maps file names, extensions and aliases to a canonical language name, and
  gives each language a token specification: an ordered list of
  {class, re} entries. Earlier entries win when two could start at the
  same position. Every regex must consume at least one character, and may
  only use non-capturing groups (?:...) internally.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:ci="urn:dita-community:codeinclude"
                exclude-result-prefixes="#all">

  <!-- ===================================================================
       Names
       =================================================================== -->

  <!-- alias or extension (lower case) -> canonical language -->
  <xsl:variable name="ci:aliases" as="map(xs:string, xs:string)" select="map {
      'yaml':'yaml', 'yml':'yaml',
      'json':'json', 'jsonc':'json', 'json5':'json', 'geojson':'json', 'jsonld':'json', 'ipynb':'json', 'har':'json',
      'xml':'xml', 'dita':'xml', 'ditamap':'xml', 'ditaval':'xml', 'xsl':'xml', 'xslt':'xml', 'xsd':'xml',
      'svg':'xml', 'pom':'xml', 'wsdl':'xml', 'plist':'xml', 'rng':'xml', 'sch':'xml', 'xliff':'xml', 'xlf':'xml',
      'csproj':'xml', 'resx':'xml', 'fo':'xml',
      'html':'html', 'htm':'html', 'xhtml':'html', 'vue':'html',
      'bash':'bash', 'sh':'bash', 'shell':'bash', 'zsh':'bash', 'ksh':'bash', 'console':'bash', 'shellscript':'bash',
      'python':'python', 'py':'python', 'pyi':'python', 'py3':'python',
      'javascript':'javascript', 'js':'javascript', 'mjs':'javascript', 'cjs':'javascript', 'jsx':'javascript',
      'typescript':'typescript', 'ts':'typescript', 'tsx':'typescript', 'mts':'typescript', 'cts':'typescript',
      'java':'java', 'groovy':'java', 'gradle':'java',
      'kotlin':'kotlin', 'kt':'kotlin', 'kts':'kotlin',
      'scala':'scala', 'sc':'scala',
      'go':'go', 'golang':'go',
      'rust':'rust', 'rs':'rust',
      'c':'c', 'h':'c',
      'cpp':'cpp', 'c++':'cpp', 'cc':'cpp', 'cxx':'cpp', 'hpp':'cpp', 'hh':'cpp', 'hxx':'cpp',
      'csharp':'csharp', 'cs':'csharp', 'c#':'csharp',
      'swift':'swift', 'dart':'dart', 'php':'php',
      'ruby':'ruby', 'rb':'ruby', 'rake':'ruby', 'gemspec':'ruby',
      'perl':'perl', 'pl':'perl', 'pm':'perl',
      'lua':'lua',
      'r':'r',
      'powershell':'powershell', 'ps1':'powershell', 'psm1':'powershell', 'pwsh':'powershell',
      'sql':'sql', 'psql':'sql', 'mysql':'sql', 'plsql':'sql',
      'css':'css', 'scss':'css', 'less':'css',
      'ini':'ini', 'cfg':'ini', 'conf':'ini', 'cnf':'ini', 'desktop':'ini', 'service':'ini', 'editorconfig':'ini',
      'gitconfig':'ini',
      'properties':'properties', 'env':'properties', 'dotenv':'properties',
      'toml':'toml', 'lock':'toml',
      'hcl':'hcl', 'tf':'hcl', 'tfvars':'hcl', 'nomad':'hcl',
      'dockerfile':'dockerfile', 'docker':'dockerfile', 'containerfile':'dockerfile',
      'make':'make', 'makefile':'make', 'mk':'make', 'mak':'make',
      'diff':'diff', 'patch':'diff',
      'markdown':'markdown', 'md':'markdown', 'mdx':'markdown',
      'protobuf':'protobuf', 'proto':'protobuf',
      'graphql':'graphql', 'gql':'graphql',
      'text':'text', 'txt':'text', 'plaintext':'text', 'plain':'text', 'log':'text', 'csv':'text', 'tsv':'text'
    }"/>

  <!-- whole file names (lower case) that identify a language -->
  <xsl:variable name="ci:filenames" as="map(xs:string, xs:string)" select="map {
      'dockerfile':'dockerfile', 'containerfile':'dockerfile',
      'makefile':'make', 'gnumakefile':'make',
      'jenkinsfile':'java', 'vagrantfile':'ruby', 'gemfile':'ruby', 'rakefile':'ruby',
      '.bashrc':'bash', '.bash_profile':'bash', '.zshrc':'bash', '.profile':'bash',
      '.gitconfig':'ini', '.editorconfig':'ini', '.npmrc':'ini',
      '.env':'properties', 'cmakelists.txt':'make',
      'go.mod':'go', 'cargo.lock':'toml'
    }"/>

  <!-- Normalise an alias, extension or MIME-ish name to a canonical language, or '' -->
  <xsl:function name="ci:canonical-language" as="xs:string">
    <xsl:param name="name" as="xs:string?"/>
    <xsl:variable name="n" select="lower-case(normalize-space($name))
                                   => replace('^(text|application)/(x-)?', '')
                                   => replace('\+.*$', '')"/>
    <xsl:sequence select="if ($n = '') then '' else ($ci:aliases($n), '')[1]"/>
  </xsl:function>

  <!-- Detect a language from a path or URL -->
  <xsl:function name="ci:language-from-path" as="xs:string">
    <xsl:param name="href" as="xs:string?"/>
    <xsl:variable name="path" select="replace(string($href), '[?#].*$', '')"/>
    <xsl:variable name="file" select="lower-case(tokenize($path, '[/\\]')[last()])"/>
    <xsl:variable name="ext" select="if (contains($file, '.')) then tokenize($file, '\.')[last()] else ''"/>
    <xsl:sequence select="($ci:filenames($file),
                           if (starts-with($file, 'dockerfile.') or ends-with($file, '.dockerfile')) then 'dockerfile' else (),
                           if ($ext != '') then $ci:aliases($ext) else (),
                           '')[1]"/>
  </xsl:function>

  <!-- ===================================================================
       Shared regex building blocks
       =================================================================== -->

  <xsl:variable name="ci:never" as="xs:string">[^\s\S]</xsl:variable>
  <xsl:variable name="ci:re-dq" as="xs:string">"(?:[^"\\\n]|\\.)*"</xsl:variable>
  <xsl:variable name="ci:re-sq" as="xs:string">'(?:[^'\\\n]|\\.)*'</xsl:variable>
  <xsl:variable name="ci:re-sq-raw" as="xs:string">'[^'\n]*'</xsl:variable>
  <xsl:variable name="ci:re-bt" as="xs:string">`(?:[^`\\]|\\[\s\S])*`</xsl:variable>
  <xsl:variable name="ci:re-triple" as="xs:string">"""[\s\S]*?"""|'''[\s\S]*?'''</xsl:variable>
  <xsl:variable name="ci:re-hash-comment" as="xs:string">#[^\n]*</xsl:variable>
  <xsl:variable name="ci:re-slash-comment" as="xs:string">//[^\n]*</xsl:variable>
  <xsl:variable name="ci:re-block-comment" as="xs:string">/\*[\s\S]*?\*/</xsl:variable>
  <xsl:variable name="ci:re-dash-comment" as="xs:string">--[^\n]*</xsl:variable>
  <xsl:variable name="ci:re-number" as="xs:string">0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9][0-9_]*(?:\.[0-9][0-9_]*)?(?:[eE][+\-]?[0-9]+)?[lLfFdDuUnmi]*</xsl:variable>
  <xsl:variable name="ci:re-ident" as="xs:string">[A-Za-z_][A-Za-z0-9_]*</xsl:variable>
  <xsl:variable name="ci:re-shell-var" as="xs:string">\$\{[^}\n]*\}|\$\([A-Za-z_][A-Za-z0-9_]*\)|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9#?@*$!\-]</xsl:variable>
  <xsl:variable name="ci:re-punct" as="xs:string">[{}\[\]();,.:=+\-*/%&lt;&gt;!&amp;|^~?]+</xsl:variable>

  <!-- ===================================================================
       Keywords
       =================================================================== -->

  <xsl:function name="ci:words" as="xs:string*">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="tokenize(normalize-space($s), ' ')"/>
  </xsl:function>

  <xsl:variable name="ci:keywords" as="map(xs:string, xs:string*)" select="map {
      'bash': ci:words('if then else elif fi case esac for select while until do done in function time
                        return exit break continue local export readonly declare typeset unset shift source
                        alias set trap eval exec echo printf read cd test'),
      'python': ci:words('and as assert async await break class continue def del elif else except finally
                          for from global if import in is lambda nonlocal not or pass raise return try while
                          with yield match case print self'),
      'javascript': ci:words('async await break case catch class const continue debugger default delete do
                              else export extends finally for from function get if import in instanceof let new
                              of return set static super switch this throw try typeof var void while with yield'),
      'typescript': ci:words('abstract any as async await boolean break case catch class const constructor
                              continue declare default delete do else enum export extends finally for from
                              function get if implements import in infer instanceof interface is keyof let
                              module namespace never new number object of private protected public readonly
                              return satisfies set static string super switch symbol this throw try type typeof
                              unknown var void while yield'),
      'java': ci:words('abstract assert boolean break byte case catch char class const continue default do
                        double else enum extends final finally float for goto if implements import instanceof
                        int interface long native new package private protected public record return short
                        static strictfp super switch synchronized this throw throws transient try var void
                        volatile while yield sealed permits def'),
      'kotlin': ci:words('as break class continue do else for fun if in interface is object package return
                          super this throw try typealias typeof val var when while by catch constructor
                          companion data enum finally get import init internal lateinit open override private
                          protected public sealed set suspend'),
      'scala': ci:words('abstract case catch class def do else extends final finally for forSome if implicit
                         import lazy match new object override package private protected return sealed super
                         this throw trait try type val var while with yield given using enum then'),
      'go': ci:words('break case chan const continue default defer else fallthrough for func go goto if import
                      interface map package range return select struct switch type var
                      bool byte error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16
                      uint32 uint64 uintptr any'),
      'rust': ci:words('as async await break const continue crate dyn else enum extern fn for if impl in let
                        loop match mod move mut pub ref return self Self static struct super trait type unsafe
                        use where while i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char
                        str String Vec Option Result Box'),
      'c': ci:words('auto break case char const continue default do double else enum extern float for goto
                     if inline int long register restrict return short signed sizeof static struct switch
                     typedef union unsigned void volatile while include define ifdef ifndef endif pragma'),
      'cpp': ci:words('alignas alignof auto bool break case catch char class const constexpr const_cast
                       continue decltype default delete do double dynamic_cast else enum explicit export extern
                       float for friend goto if inline int long mutable namespace new noexcept operator private
                       protected public register reinterpret_cast return short signed sizeof static
                       static_assert static_cast struct switch template this thread_local throw try typedef
                       typeid typename union unsigned using virtual void volatile while include define ifdef
                       ifndef endif pragma std'),
      'csharp': ci:words('abstract as base bool break byte case catch char checked class const continue
                          decimal default delegate do double else enum event explicit extern finally fixed
                          float for foreach goto if implicit in int interface internal is lock long namespace
                          new object operator out override params private protected public readonly record ref
                          return sbyte sealed short sizeof stackalloc static string struct switch this throw try
                          typeof uint ulong unchecked unsafe ushort using var virtual void volatile while async
                          await get set init yield'),
      'swift': ci:words('associatedtype class deinit enum extension fileprivate func import init inout internal
                         let open operator private protocol public rethrows static struct subscript typealias
                         var break case continue default defer do else fallthrough for guard if in repeat return
                         switch where while as catch is super self Self throw throws try async await'),
      'dart': ci:words('abstract as assert async await break case catch class const continue covariant default
                        deferred do dynamic else enum export extends extension external factory final finally
                        for get if implements import in interface is late library mixin new on operator part
                        required rethrow return set show static super switch sync this throw try typedef var
                        void while with yield'),
      'php': ci:words('abstract and array as break callable case catch class clone const continue declare
                       default do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile
                       extends final finally fn for foreach function global goto if implements include
                       instanceof insteadof interface isset list match namespace new or print private protected
                       public readonly require return static switch throw trait try unset use var while yield'),
      'ruby': ci:words('alias and begin break case class def defined do else elsif end ensure for if in module
                        next not or redo rescue retry return self super then undef unless until when while
                        yield require attr_accessor attr_reader puts'),
      'perl': ci:words('my our local sub if elsif else unless while until for foreach last next redo return use
                        package require print die eval do'),
      'lua': ci:words('and break do else elseif end for function goto if in local not or repeat return then
                       until while'),
      'r': ci:words('if else repeat while function for in next break library require return'),
      'powershell': ci:words('begin break catch class continue data do dynamicparam else elseif end exit filter
                              finally for foreach from function if in param process return switch throw trap try
                              until using var while'),
      'sql': ci:words('SELECT FROM WHERE AND OR NOT IN IS NULL AS ON JOIN LEFT RIGHT INNER OUTER FULL CROSS
                       GROUP BY ORDER HAVING LIMIT OFFSET INSERT INTO VALUES UPDATE SET DELETE CREATE TABLE
                       VIEW INDEX DROP ALTER ADD COLUMN PRIMARY KEY FOREIGN REFERENCES UNIQUE DEFAULT CHECK
                       CONSTRAINT DISTINCT UNION ALL EXISTS BETWEEN LIKE CASE WHEN THEN ELSE END ASC DESC WITH
                       RETURNING GRANT REVOKE BEGIN COMMIT ROLLBACK TRANSACTION IF REPLACE TRUNCATE DATABASE
                       SCHEMA INT INTEGER BIGINT SMALLINT VARCHAR CHAR TEXT BOOLEAN DATE TIMESTAMP NUMERIC
                       DECIMAL SERIAL'),
      'css': ci:words('important media import from to keyframes supports font-face'),
      'hcl': ci:words('resource data variable output module provider terraform locals for in if each count
                       dynamic content'),
      'dockerfile': ci:words('FROM RUN CMD LABEL MAINTAINER EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR
                              ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL AS'),
      'make': ci:words('ifeq ifneq ifdef ifndef else endif include define endef export unexport override
                        vpath PHONY'),
      'protobuf': ci:words('syntax package import option message enum service rpc returns repeated optional
                            required oneof map reserved extend stream double float int32 int64 uint32 uint64
                            sint32 sint64 fixed32 fixed64 sfixed32 sfixed64 bool string bytes'),
      'graphql': ci:words('query mutation subscription fragment on type interface union enum input scalar
                           schema extend directive implements')
    }"/>

  <xsl:variable name="ci:literals" as="map(xs:string, xs:string*)" select="map {
      'python': ci:words('True False None'),
      'ruby': ci:words('true false nil'),
      'lua': ci:words('true false nil'),
      'go': ci:words('true false nil iota'),
      'rust': ci:words('true false None Some Ok Err'),
      'swift': ci:words('true false nil'),
      'r': ci:words('TRUE FALSE NULL NA Inf NaN'),
      'powershell': ci:words('$true $false $null'),
      'sql': ci:words('TRUE FALSE NULL'),
      'bash': ci:words('true false'),
      '*': ci:words('true false null undefined NaN Infinity')
    }"/>

  <!-- languages whose keywords are matched case-insensitively -->
  <xsl:variable name="ci:case-insensitive" as="xs:string*" select="('sql', 'dockerfile', 'powershell')"/>

  <!-- ===================================================================
       Token specifications
       =================================================================== -->

  <xsl:function name="ci:t" as="map(*)">
    <xsl:param name="class" as="xs:string"/>
    <xsl:param name="re" as="xs:string"/>
    <xsl:sequence select="map { 'class': $class, 're': $re }"/>
  </xsl:function>

  <xsl:variable name="ci:spec-c-like" as="map(*)*" select="(
      ci:t('comment', $ci:re-block-comment),
      ci:t('comment', $ci:re-slash-comment),
      ci:t('meta', '^[ \t]*#[ \t]*[a-z]+'),
      ci:t('string', $ci:re-dq),
      ci:t('string', $ci:re-sq),
      ci:t('meta', '@[A-Za-z_][A-Za-z0-9_.]*'),
      ci:t('number', $ci:re-number),
      ci:t('ident', $ci:re-ident))"/>

  <xsl:variable name="ci:spec-js" as="map(*)*" select="(
      ci:t('comment', $ci:re-block-comment),
      ci:t('comment', $ci:re-slash-comment),
      ci:t('string', $ci:re-bt),
      ci:t('string', $ci:re-dq),
      ci:t('string', $ci:re-sq),
      ci:t('meta', '@[A-Za-z_][A-Za-z0-9_.]*'),
      ci:t('number', $ci:re-number),
      ci:t('ident', '[A-Za-z_$][A-Za-z0-9_$]*'))"/>

  <xsl:variable name="ci:spec" as="map(xs:string, map(*)*)" select="map {
      'json': (
        ci:t('comment', $ci:re-block-comment),
        ci:t('comment', $ci:re-slash-comment),
        ci:t('json-key', $ci:re-dq || '\s*:'),
        ci:t('string', $ci:re-dq),
        ci:t('number', '-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+\-]?[0-9]+)?'),
        ci:t('literal', 'true|false|null'),
        ci:t('punct', '[{}\[\],:]')),

      'xml': (
        ci:t('comment', '&lt;!--[\s\S]*?--&gt;'),
        ci:t('cdata', '&lt;!\[CDATA\[[\s\S]*?\]\]&gt;'),
        ci:t('meta', '&lt;\?[\s\S]*?\?&gt;'),
        ci:t('meta', '&lt;![A-Za-z][^&gt;]*&gt;'),
        ci:t('xml-tag', '&lt;/?[A-Za-z_:][^&lt;&gt;]*&gt;'),
        ci:t('entity', '&amp;[#A-Za-z0-9_.\-]+;')),

      'bash': (
        ci:t('comment', '^[ \t]*#[^\n]*|[ \t]#[^\n]*'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq-raw),
        ci:t('string', $ci:re-bt),
        ci:t('variable', $ci:re-shell-var),
        ci:t('meta', '^[ \t]*[$#] '),
        ci:t('option', '[ \t]--?[A-Za-z][A-Za-z0-9\-]*'),
        ci:t('number', '[0-9]+(?:\.[0-9]+)?'),
        ci:t('ident', $ci:re-ident)),

      'python': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', '(?:[rRbBuUfF]{1,2})?(?:' || $ci:re-triple || ')'),
        ci:t('string', '(?:[rRbBuUfF]{1,2})?(?:' || $ci:re-dq || '|' || $ci:re-sq || ')'),
        ci:t('meta', '@[A-Za-z_][A-Za-z0-9_.]*'),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'ruby': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('literal', ':[A-Za-z_][A-Za-z0-9_]*[?!]?'),
        ci:t('variable', '@{1,2}[A-Za-z_][A-Za-z0-9_]*|\$[A-Za-z_][A-Za-z0-9_]*'),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'perl': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('variable', '[$@%][A-Za-z_][A-Za-z0-9_]*'),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'r': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('number', $ci:re-number),
        ci:t('ident', '[A-Za-z_.][A-Za-z0-9_.]*')),

      'powershell': (
        ci:t('comment', '&lt;#[\s\S]*?#&gt;'),
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq-raw),
        ci:t('variable', '\$[A-Za-z_][A-Za-z0-9_:]*'),
        ci:t('option', '[ \t]-[A-Za-z][A-Za-z0-9]*'),
        ci:t('number', $ci:re-number),
        ci:t('ident', '[A-Za-z_][A-Za-z0-9_\-]*')),

      'lua': (
        ci:t('comment', '--\[\[[\s\S]*?\]\]'),
        ci:t('comment', $ci:re-dash-comment),
        ci:t('string', '\[\[[\s\S]*?\]\]'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'sql': (
        ci:t('comment', $ci:re-block-comment),
        ci:t('comment', $ci:re-dash-comment),
        ci:t('string', $ci:re-sq),
        ci:t('ident', $ci:re-dq),
        ci:t('variable', '[:@$][A-Za-z_][A-Za-z0-9_]*|\$[0-9]+'),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'css': (
        ci:t('comment', $ci:re-block-comment),
        ci:t('comment', $ci:re-slash-comment),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('meta', '@[A-Za-z\-]+'),
        ci:t('key', '^[ \t]+[A-Za-z\-]+[ \t]*:'),
        ci:t('variable', '\$[A-Za-z_\-][A-Za-z0-9_\-]*|--[A-Za-z0-9_\-]+'),
        ci:t('number', '#[0-9a-fA-F]{3,8}|-?[0-9]*\.?[0-9]+(?:px|em|rem|%|vh|vw|s|ms|deg|pt|cm|mm|in|fr|ch)?'),
        ci:t('tag', '[.#][A-Za-z_\-][A-Za-z0-9_\-]*|[A-Za-z][A-Za-z0-9\-]*')),

      'ini': (
        ci:t('comment', '^[ \t]*[#;][^\n]*'),
        ci:t('section', '^[ \t]*\[[^\]\n]*\]'),
        ci:t('ini-key', '^[ \t]*[^=:#;\[\s][^=:\n]*'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('number', '[0-9]+(?:\.[0-9]+)?'),
        ci:t('ident', $ci:re-ident)),

      'properties': (
        ci:t('comment', '^[ \t]*[#!][^\n]*'),
        ci:t('ini-key', '^[ \t]*(?:export[ \t]+)?[^=:#!\s][^=:\n]*'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq),
        ci:t('variable', $ci:re-shell-var)),

      'toml': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('section', '^[ \t]*\[\[?[^\]\n]*\]\]?'),
        ci:t('ini-key', '^[ \t]*[A-Za-z0-9_\-.&quot;'']+(?:[ \t]*\.[ \t]*[A-Za-z0-9_\-&quot;'']+)*[ \t]*='),
        ci:t('string', $ci:re-triple),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq-raw),
        ci:t('number', '[+\-]?(?:0x[0-9a-fA-F_]+|[0-9][0-9_:\-T.]*(?:[eE][+\-]?[0-9]+)?Z?)'),
        ci:t('ident', $ci:re-ident)),

      'hcl': (
        ci:t('comment', $ci:re-block-comment),
        ci:t('comment', $ci:re-slash-comment),
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', '&lt;&lt;-?[A-Z]+\n[\s\S]*?\n[ \t]*[A-Z]+'),
        ci:t('string', $ci:re-dq),
        ci:t('ini-key', '^[ \t]*[A-Za-z_][A-Za-z0-9_\-]*[ \t]*='),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'dockerfile': (
        ci:t('comment', '^[ \t]*#[^\n]*'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq-raw),
        ci:t('variable', $ci:re-shell-var),
        ci:t('option', '[ \t]--[A-Za-z][A-Za-z0-9\-]*'),
        ci:t('ident', $ci:re-ident)),

      'make': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('section', '^[A-Za-z0-9_.%/\-$(){}][A-Za-z0-9_.%/\-$(){} ]*::?(?:[ \t]|$)'),
        ci:t('variable', $ci:re-shell-var || '|\$[@&lt;^?*%+]'),
        ci:t('string', $ci:re-dq),
        ci:t('string', $ci:re-sq-raw),
        ci:t('ident', $ci:re-ident)),

      'diff': (
        ci:t('meta', '^(?:diff|index|---|\+\+\+)[^\n]*'),
        ci:t('section', '^@@[^\n]*'),
        ci:t('inserted', '^\+[^\n]*'),
        ci:t('deleted', '^-[^\n]*')),

      'markdown': (
        ci:t('comment', '&lt;!--[\s\S]*?--&gt;'),
        ci:t('section', '^#{1,6}[ \t][^\n]*'),
        ci:t('string', '^```[^\n]*\n[\s\S]*?\n```|`[^`\n]+`'),
        ci:t('meta', '^[ \t]*(?:[*+\-]|[0-9]+\.)[ \t]'),
        ci:t('keyword', '\*\*[^*\n]+\*\*|__[^_\n]+__'),
        ci:t('variable', '!?\[[^\]\n]*\]\([^)\n]*\)')),

      'graphql': (
        ci:t('comment', $ci:re-hash-comment),
        ci:t('string', '&quot;&quot;&quot;[\s\S]*?&quot;&quot;&quot;'),
        ci:t('string', $ci:re-dq),
        ci:t('variable', '\$[A-Za-z_][A-Za-z0-9_]*'),
        ci:t('meta', '@[A-Za-z_][A-Za-z0-9_]*'),
        ci:t('number', $ci:re-number),
        ci:t('ident', $ci:re-ident)),

      'javascript': $ci:spec-js,
      'typescript': $ci:spec-js,
      'java': $ci:spec-c-like,
      'kotlin': $ci:spec-c-like,
      'scala': $ci:spec-c-like,
      'c': $ci:spec-c-like,
      'cpp': $ci:spec-c-like,
      'csharp': $ci:spec-c-like,
      'swift': $ci:spec-c-like,
      'dart': $ci:spec-c-like,
      'protobuf': $ci:spec-c-like,
      'go': ($ci:spec-c-like[1], $ci:spec-c-like[2], ci:t('string', $ci:re-bt), $ci:spec-c-like[position() gt 2]),
      'rust': $ci:spec-c-like,
      'php': (ci:t('comment', $ci:re-hash-comment), ci:t('variable', '\$[A-Za-z_][A-Za-z0-9_]*'), $ci:spec-c-like)
    }"/>

</xsl:stylesheet>
