"""Validate wiki page frontmatter against schema/wiki-page.schema.json.

Usage: uv run --with jsonschema --with pyyaml python validate_pages.py examples/*.md
Also checks that every [^id] footnote in the body names a sources[].id.
"""
import json, pathlib, re, sys

import jsonschema
import yaml

schema = json.loads((pathlib.Path(__file__).parent / "schema/wiki-page.schema.json").read_text())
validator = jsonschema.Draft202012Validator(schema)
failed = 0
for path in sys.argv[1:]:
    text = pathlib.Path(path).read_text()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        print(f"FAIL {path}: no frontmatter"); failed += 1; continue
    fm, body = yaml.safe_load(m.group(1)), m.group(2)
    errors = [f"{'/'.join(map(str, e.path)) or '(root)'}: {e.message}" for e in validator.iter_errors(fm)]
    source_ids = {s.get("id") for s in fm.get("sources", []) if isinstance(s, dict)}
    cited = set(re.findall(r"\[\^([\w-]+)\](?!:)", body))
    errors += [f"footnote [^{c}] has no sources[].id" for c in sorted(cited - source_ids)]
    print(("FAIL " if errors else "ok   ") + path)
    for e in errors:
        print("     " + e)
    failed += bool(errors)
sys.exit(1 if failed else 0)
