# org.dita-community.codeinclude

A DITA Open Toolkit plugin that pulls code files into `<codeblock>` through `<coderef href="...">` and highlights them in the language of the file. The href can be a local path or an `http(s)` URL, so a YAML file sitting in a GitHub repository can be documented without copying it into your source tree.

```xml
<codeblock>
  <coderef scope="external"
    href="https://github.com/red-hat-data-services/kserve/blob/287b7c925e9a0e3243c2a7477550d346c8027f7a/config/llmisvcconfig/config-llm-scheduler-eppconfig-default.yaml"/>
</codeblock>
```

The plugin fetches the raw file, sees `.yaml`, adds `outputclass="language-yaml"` and wraps keys, strings, numbers, comments and punctuation in `<ph outputclass="hl-*">` tokens. HTML5 and PDF both come out coloured.

Requires DITA-OT 4.x (Saxon HE 12, XSLT 3.0).

Example output: [codeinclude sample](https://aireilly.github.io/org.dita-community.codeinclude/)

## Compared with DITA include and coderef

DITA already has two ways to pull a text file into a codeblock: `<coderef>` (DITA 1.2 and later) and, in DITA 2.0, [`<include parse="text">`](https://dita-lang.org/2.0/dita/langref/base/include). This is what stock DITA-OT 4.3.4 does with them, without the plugin:

| | Stock `<coderef>` | Stock `<include parse="text">` | With this plugin |
| --- | --- | --- | --- |
| Local file | Included | Included in DITA 2.0 topics. DITA 1.3 topics reject the element. DITA-OT also tries to parse the file as XML and logs DOTJ013E | Included, inside `codeinclude.local.root` only |
| Remote `https://` file | Dropped: empty codeblock, no error | Dropped: empty codeblock, no error | Fetched, from allowed hosts only |
| GitHub, GitLab, Bitbucket and Gitea "view file" URLs | Not fetched | Not fetched | Rewritten to the raw file and fetched |
| `#line-range(13,19)`, `#line=12,19`, `#token=A,B` | Supported | Supported | Supported, local and remote |
| `#L13-L19` (copied from GitHub) | Ignored: the whole file is included | Ignored: the whole file is included | Supported |
| Syntax highlighting | None | None | At build time, in HTML5 and PDF, for about 40 languages |
| `language-x` class from the file name | No | No | Yes, so highlight.js or Prism can also take over |
| Missing file | Error, empty codeblock, build continues | Error, empty codeblock, build continues | Warning, or a failed build with `codeinclude.fail-on-error=yes` |
| Line range past the end of the file | Empty codeblock, no message | Empty codeblock, no message | CINC007 warning, or a failed build with `codeinclude.fail-on-error=yes` |

If your code files are local and you don't need highlighting, stock `<coderef>` is enough and you don't need this plugin.

## Install

Install the latest release straight from GitHub:

```sh
dita install https://github.com/aireilly/org.dita-community.codeinclude/releases/latest/download/org.dita-community.codeinclude.zip
```

Every push to `main` publishes a release tagged `v<version>-<build number>`, for example `v1.0.0-12`. To install a specific build, download its zip from the [releases page](https://github.com/aireilly/org.dita-community.codeinclude/releases) and run `dita install org.dita-community.codeinclude.zip`. The plugin installs as `org.dita-community.codeinclude`, which is the name to use with `dita uninstall` and in `<require plugin="..."/>`.

## Network access

The build fetches remote coderefs while it runs, so the machine or container that runs `dita` needs outbound https access to the hosts in `codeinclude.remote.allow-hosts`. Nothing is cached between builds.

If your build environment has no internet access, or policy doesn't allow fetching during a build, keep the code files in your repository and use local coderefs such as `<coderef href="code/app.yaml"/>`. Local files get the same line selection and highlighting. Set `codeinclude.remote=no` so any remaining remote coderef is reported instead of attempted, and add `codeinclude.fail-on-error=yes` to make that report fail the build.

## Writing coderefs

Anything the built-in coderef accepts still works. On top of that:

| href | Result |
| --- | --- |
| `code/app.yaml` | Local file, resolved the way DITA-OT does it |
| `https://raw.githubusercontent.com/o/r/main/app.yaml` | Fetched as is |
| `https://github.com/o/r/blob/main/app.yaml` | Rewritten to `raw.githubusercontent.com` |
| `https://gitlab.com/o/r/-/blob/main/app.yaml` | Rewritten to `/-/raw/` (any GitLab host) |
| `https://bitbucket.org/o/r/src/main/app.yaml` | Rewritten to `/raw/` |
| `https://codeberg.org/o/r/src/branch/main/app.yaml` | Rewritten to `/raw/branch/` (Gitea and Forgejo on any host, for `/owner/repo/src/branch\|tag\|commit/` paths) |

Put `scope="external"` on remote coderefs so the DITA-OT reader leaves the URL alone.

Prefer a commit hash over a branch name in remote URLs (`/blob/3f9c2e1.../config.yaml`). A branch can change after you publish, and the build warns when it sees one.

### Selecting lines

The fragment picks part of the file. These work for local and remote files:

| Fragment | Meaning |
| --- | --- |
| `#L13-L19`, `#L13` | GitHub style, 1-based, inclusive. Copy it straight from the GitHub UI. |
| `#line-range(13,19)` | DITA-OT style, 1-based, inclusive |
| `#line=12,19` | RFC 5147 line positions |
| `#token=BEGIN,END` | Lines strictly between the lines containing `BEGIN` and `END` |

A fragment that selects no lines, such as a range past the end of the file or a token that doesn't occur, is reported as CINC007 and leaves the codeblock empty. With `codeinclude.fail-on-error=yes` it fails the build.

Add `outputclass="normalize-space"` to the codeblock to strip the indentation shared by every selected line, which matters when you lift a nested block out of a YAML file.

### Choosing the language

The first of these that gives an answer wins:

1. `outputclass` on the codeblock: `language-yaml`, `lang-yaml`, or a bare known name such as `yaml`.
2. The first part of `coderef/@format` (`format="json"` or `format="yaml; charset=UTF-8"`). `text` and `txt` are ignored here, since many projects put them on every coderef.
3. The file name: extension, or well known names like `Dockerfile` and `Makefile`.
4. The `codeinclude.default-language` parameter.

Highlighted: YAML, JSON, XML (DITA, XSLT, SVG, POM...), HTML, Bash/shell, Python, JavaScript, TypeScript, Java, Kotlin, Scala, Go, Rust, C, C++, C#, Swift, Dart, PHP, Ruby, Perl, Lua, R, PowerShell, SQL, CSS, INI, `.properties`/`.env`, TOML, HCL/Terraform, Dockerfile, Makefile, diff/patch, Markdown, Protocol Buffers and GraphQL. Any other language still gets its `language-x` class and renders as plain text.

Inline code works too. A codeblock with `outputclass="language-json"` and no coderef is highlighted the same way. Codeblocks that already contain markup such as `<ph>` or `<b>` are left alone.

## Parameters

Pass them with `--name=value` on the `dita` command line.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `codeinclude.enabled` | `yes` | `no` (or `false`, `off`) hands coderef back to the built-in resolver and turns off the plugin's preprocessing and its HTML5 codeblock markup. PDF token styles stay registered but have nothing to style |
| `codeinclude.remote` | `yes` | `no` skips URL fetches (offline builds); a warning is logged per skipped coderef |
| `codeinclude.highlight` | `yes` | `no` keeps the include and the `language-x` class but drops build-time tokens, for sites that use highlight.js or Prism |
| `codeinclude.default-language` | empty | Language for codeblocks where nothing else matches |
| `codeinclude.charset` | `UTF-8` | Charset used when `@format` names none |
| `codeinclude.fail-on-error` | `no` | `yes` stops the build when a coderef is refused, cannot be read, or selects no lines. `--processing-mode=strict` does the same |
| `codeinclude.html.css` | `inline` | `none` stops the plugin embedding its token stylesheet in HTML pages |
| `codeinclude.local.root` | input map's folder | Local coderefs must resolve inside this folder. Point it at your repository root if code lives beside the docs. A relative path is resolved against the directory `dita` was started in. `*` removes the limit |
| `codeinclude.remote.allow-hosts` | `github.com raw.githubusercontent.com gitlab.com bitbucket.org codeberg.org` | Hosts remote coderefs may fetch from. Add your own Git server here. `*` allows any public host |
| `codeinclude.remote.allow-http` | `no` | `yes` allows unencrypted `http://` URLs |
| `codeinclude.remote.require-pinned` | `warn` | `yes` refuses remote URLs that follow a branch or tag; `no` silences the warning |
| `codeinclude.max-size` | `1048576` | Largest include, in characters |

Code longer than 262,144 characters, or with a line longer than 4000 characters, is included as plain text without highlighting. Both limits count characters, not bytes.

Behind a proxy, give Java the usual settings, for example `export ANT_OPTS="-Dhttps.proxyHost=proxy -Dhttps.proxyPort=3128"`, or run `dita` with `--autoproxy`.

## Output

HTML5 gets this markup, which highlight.js and Prism both understand:

```html
<pre data-language="yaml" class="pre codeblock language-yaml"><code class="language-yaml">
  <span class="ph hl-key">kind</span><span class="ph hl-punct">:</span> <span class="ph hl-string">EndpointPickerConfig</span>
```

Token classes: `hl-comment`, `hl-keyword`, `hl-key`, `hl-string`, `hl-number`, `hl-literal`, `hl-type`, `hl-variable`, `hl-meta`, `hl-tag`, `hl-attr`, `hl-option`, `hl-entity`, `hl-cdata`, `hl-section`, `hl-punct`, `hl-inserted`, `hl-deleted`.

To restyle HTML, set `codeinclude.html.css=none` and add rules for those classes to your `args.css`. To restyle PDF, redefine the attribute sets `codeinclude.hl-comment`, `codeinclude.hl-key` and so on in a PDF customization plugin.

## Security

A coderef tells the build machine to open a file or URL and publish whatever comes back. Anyone who can edit a topic can therefore try to publish files from that machine, such as SSH keys, `.env` files or CI credentials, or make the build call services that are only reachable from inside your network. The plugin treats every href as untrusted and checks it before anything is opened.

What a coderef can reach:

* **Local files** only inside `codeinclude.local.root`, checked after `..` segments are resolved. Encoded dots and slashes (`%2e`, `%2f`, `%5c`, `%00`), backslashes, `//host` and `file://host/` network paths, and every scheme except `file:`, `https:` and `http:` are refused before path resolution starts. Without an input map and without an explicit root, no local file is read at all.
* **Remote files** only over https by default, and only from hosts in `codeinclude.remote.allow-hosts`. IP addresses (including decimal, hex and IPv6 forms), `localhost`, single-label names and `.local`, `.internal` and similar suffixes are refused even when the allow list is `*`. So are `user:password@` URLs and non-default ports. Cloud metadata endpoints such as `169.254.169.254` and `metadata.google.internal` fall under these rules.
* **Size**: at most `codeinclude.max-size` characters per include. Highlighting has its own lower limits so that hostile input cannot make the regular expressions slow.

What the plugin does with the content:

* File content is only ever inserted as text. It is never parsed as XML, evaluated or executed, and DITA-OT escapes it on output, so a file containing `</code><script>` shows up as those characters on the page. `test/run_security_tests.py` covers this case.
* Language names taken from `outputclass` are reduced to `[a-z0-9+#_.-]` before they reach `class` and `data-language` attributes.

What it cannot protect against, and how to cover it:

* **Upstream changes.** If a remote file changes, your next build publishes the new version. Pin URLs to a commit hash and set `codeinclude.remote.require-pinned=yes` in CI.
* **Redirects.** Java follows redirects for the request, and the plugin only sees the URL you wrote. Java will not follow an https URL to plain http, which keeps the default setup away from http-only metadata services, but an allowed host with an open redirect could still send the request to another https host. Keep the allow list to hosts you trust.
* **DNS.** Host names are checked as text. A public name that resolves to a private address is not detected. Run builds of untrusted content on a machine or container without access to internal services.
* **Symbolic links.** A symlink inside the root that points outside it will be followed. Don't build untrusted branches in a checkout that contains such links.
* **Memory and time.** The size check runs after the download, and Java has no default network timeout. Set `ANT_OPTS="-Dsun.net.client.defaultConnectTimeout=10000 -Dsun.net.client.defaultReadTimeout=30000"` so a slow server cannot stall the build.
* **Everything else in DITA.** Authors can already put arbitrary text, links and `outputclass` values into topics without this plugin. It adds file and network access, and the controls above are for that.

For documentation built from pull requests or other contributors you don't fully trust, a reasonable CI setup is:

```sh
dita -i docs/main.ditamap -f html5 \
  --codeinclude.local.root=. \
  --codeinclude.remote.allow-hosts="github.com raw.githubusercontent.com" \
  --codeinclude.remote.require-pinned=yes \
  --codeinclude.fail-on-error=yes
```

`test/run_security_tests.py` checks 37 hostile hrefs, payloads and policy settings (`pip install saxonche`, then `python3 test/run_security_tests.py`). Run it after changing anything in `xsl/security.xsl`.

Run that build in a container with no credentials mounted and no route to internal networks. `fail-on-error` turns every refused coderef into a failed build, so nothing is silently dropped.

## How it works

* `codeinclude.init` (on `depend.preprocess.pre`) sets `build-step.coderef=false`, which tells DITA-OT not to resolve coderefs itself. The built-in resolver only reads local files and silently drops anything with a URL.
* `codeinclude.process` (on `depend.preprocess.post`) runs `xsl/codeinclude.xsl` over every temporary topic. It finds each coderef's source through `.job.xml`, falls back to `@xtrf`, applies the policy in `xsl/security.xsl`, reads the file with `unparsed-text()`, cuts out the requested lines, works out the language and calls the tokenizer in `xsl/highlight.xsl`.
* Both hooks fire for `preprocess`, `preprocess2` and `preprocess2-topic`, so html5, pdf2 and other formats built on them pick it up.
* `xsl/topicpull.xsl` (on `dita.xsl.topicpull`) passes coderefs through the topicpull step unchanged. coderef is an xref specialization, and without this topicpull would try to resolve each local code file as a link and log DOTX031E.
* The tokens are ordinary `<ph>` elements, so formats this plugin does not style still render the text correctly.

Adding a language means adding an entry to `$ci:aliases` and `$ci:spec` in `xsl/languages.xsl`: a list of `{class, regex}` pairs, tried in order.

## Sample

`samples/codeinclude-sample.ditamap` covers the GitHub URL above, a line range, local YAML, JSON and shell files, and a forced language. From the DITA-OT directory, after installing:

```sh
dita -i plugins/org.dita-community.codeinclude/samples/codeinclude-sample.ditamap -f html5 -o out
```

CI runs this command on every push to `main` and publishes the result to the example output page linked above.
