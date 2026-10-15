"""Security regression tests for org.dita-community.codeinclude.

Needs only Python 3 and SaxonC-HE:  pip install saxonche
Run:  python3 test/run_security_tests.py
Each case is a coderef href plus the outcome the policy must produce.
No network access is needed: every remote case is expected to be refused
before a request is made, except the allowed one, which may fail to fetch.
"""
import pathlib, re, sys, tempfile
import saxonche

HERE = pathlib.Path(__file__).resolve().parent
XSL = HERE.parent / "xsl" / "codeinclude.xsl"

REFUSED, INCLUDED, ATTEMPTED = "refused", "included", "attempted"
CASES = [
    ("code/ok.json", INCLUDED),
    ("../secret.env", REFUSED),
    ("../../../../../../etc/passwd", REFUSED),
    ("/etc/passwd", REFUSED),
    ("file:///etc/passwd", REFUSED),
    ("code/%2e%2e/%2e%2e/secret.env", REFUSED),
    ("code/..%2fsecret.env", REFUSED),
    ("code\\..\\..\\secret.env", REFUSED),
    ("jar:file:/tmp/x.jar!/a.txt", REFUSED),
    ("//evil.example.com/share/x.yaml", REFUSED),
    ("file://evil.example.com/share/x.yaml", REFUSED),
    ("file://localhost/etc/passwd", REFUSED),
    ("ftp://example.com/x.yaml", REFUSED),
    ("data:text/plain,hello", REFUSED),
    ("http://169.254.169.254/latest/meta-data/", REFUSED),
    ("https://169.254.169.254/latest/", REFUSED),
    ("https://2130706433/x", REFUSED),
    ("https://0x7f000001/x", REFUSED),
    ("https://[::1]/x", REFUSED),
    ("https://localhost/x", REFUSED),
    ("https://localhost./x", REFUSED),
    ("https://intranet/x", REFUSED),
    ("https://metadata.google.internal/computeMetadata/v1/", REFUSED),
    ("https://github.com@evil.example.com/x.yaml", REFUSED),
    ("https://github.com:8443/o/r/blob/main/x.yaml", REFUSED),
    ("https://evil.example.com/x.yaml", REFUSED),
    ("https://github.com/o/r/blob/main/x.yaml", ATTEMPTED),
    ("code/huge.txt", REFUSED),
    ("code/ok.json#L1", INCLUDED),
    ("code/ok.json#L5-L9", REFUSED),
    ("code/ok.json#L0", REFUSED),
    ("code/ok.json#token=NOPE,END", REFUSED),
]

# Policies other than the default: (description, xslt params, href, expected)
EXTRA = [
    ("relative local.root resolved against cwd", {"local-root": "src", "cwd": "{work}"}, "code/ok.json", INCLUDED),
    ("relative local.root does not widen access", {"local-root": "src", "cwd": "{work}"}, "../secret.env", REFUSED),
    ("relative local.root without cwd reads nothing", {"local-root": "src"}, "code/ok.json", REFUSED),
    ("local.root=* still refuses file://host", {"local-root": "*"}, "file://evil.example.com/x.yaml", REFUSED),
]

def transform(work, topic, params):
    out = work / "out.dita"
    with saxonche.PySaxonProcessor(license=False) as p:
        ex = p.new_xslt30_processor().compile_stylesheet(stylesheet_file=str(XSL))
        for name, value in params.items():
            ex.set_parameter(name, p.make_string_value(value.format(work=work)))
        ex.transform_to_file(source_file=str(topic), output_file=str(out))
    return out.read_text()

def body_of(result, block_id):
    m = re.search(rf'<codeblock[^>]*id="{block_id}"[^>]*?(/>|>(.*?)</codeblock>)', result, re.S)
    return (m.group(2) or "") if m else ""

def main():
    work = pathlib.Path(tempfile.mkdtemp(prefix="codeinclude-sec-"))
    src = work / "src"; (src / "code").mkdir(parents=True)
    (work / "secret.env").write_text("SECRET=hunter2\n")
    (src / "code" / "ok.json").write_text('{"a": 1}\n')
    (src / "code" / "xss.yaml").write_text("</code></pre><script>alert(1)</script>\n")
    (src / "code" / "huge.txt").write_text("x" * 2_000_000)
    blocks = "".join(
        f'<codeblock class="+ topic/pre pr-d/codeblock " id="c{i}"><coderef class="+ topic/xref pr-d/coderef " href="{h.replace("&", "&amp;")}"/></codeblock>\n'
        for i, (h, _) in enumerate(CASES))
    blocks += '<codeblock class="+ topic/pre pr-d/codeblock " id="xss"><coderef class="+ topic/xref pr-d/coderef " href="code/xss.yaml"/></codeblock>\n'
    topic = work / "t.dita"
    topic.write_text(f'<topic class="- topic/topic " id="t" xtrf="{src.as_uri()}/t.dita"><title class="- topic/title ">T</title>'
                     f'<body class="- topic/body ">{blocks}</body></topic>')
    result = transform(work, topic, {"input": str(src / "map.ditamap")})
    failures = 0
    for i, (href, want) in enumerate(CASES):
        body = body_of(result, f"c{i}")
        got = INCLUDED if body.strip() else REFUSED
        ok = got == want or (want == ATTEMPTED)
        if "hunter2" in body or "root:" in body:
            ok = False
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {want:9}  {href}")
    xss = re.search(r'id="xss"[^>]*>(.*?)</codeblock>', result, re.S).group(1)
    xss_ok = "<script>" not in xss and "&lt;script&gt;" in xss
    failures += not xss_ok
    print(f"{'PASS' if xss_ok else 'FAIL'}  escaped    file content containing <script>")
    for desc, params, href, want in EXTRA:
        one = work / "one.dita"
        one.write_text(f'<topic class="- topic/topic " id="t" xtrf="{src.as_uri()}/t.dita"><title class="- topic/title ">T</title>'
                       f'<body class="- topic/body "><codeblock class="+ topic/pre pr-d/codeblock " id="x">'
                       f'<coderef class="+ topic/xref pr-d/coderef " href="{href}"/></codeblock></body></topic>')
        body = body_of(transform(work, one, params), "x")
        got = INCLUDED if body.strip() else REFUSED
        ok = got == want and "hunter2" not in body
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {want:9}  {href}  ({desc})")
    total = len(CASES) + 1 + len(EXTRA)
    print(f"\n{total - failures} passed, {failures} failed")
    sys.exit(1 if failures else 0)

if __name__ == "__main__":
    main()
