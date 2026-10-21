#!/usr/bin/env python3
"""Lists dependency licenses for the mobile app (pubspec.lock + pub cache) and the
admin server (production npm deps). Prints TSV; flags anything not in the
permissive allow-list so it gets a human review before release.

    python3 tools/license_report.py            # needs `flutter pub get` and `npm ci` done
"""
import json, os, subprocess, sys
import yaml  # pip install pyyaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALLOWED = {"MIT", "Apache-2.0", "BSD-3-Clause", "BSD-2-Clause", "ISC", "0BSD", "Zlib"}

def classify(text):
    if "Apache License" in text: return "Apache-2.0"
    if "Permission is hereby granted, free of charge" in text: return "MIT"
    if "Redistribution and use in source and binary forms" in text:
        return "BSD-3-Clause" if "neither the name" in text.lower() else "BSD-2-Clause"
    for k, v in [("Mozilla Public License", "MPL-2.0"), ("GNU LESSER", "LGPL"), ("GNU GENERAL", "GPL")]:
        if k in text: return v
    return "UNKNOWN"

def dart():
    lock = yaml.safe_load(open(os.path.join(ROOT, "mobile", "pubspec.lock")))
    cache = os.path.expanduser(os.environ.get("PUB_CACHE", "~/.pub-cache")) + "/hosted/pub.dev"
    for name, info in sorted(lock["packages"].items()):
        if info.get("source") != "hosted":
            yield ("dart", name, "sdk", "BSD-3-Clause"); continue
        d = os.path.join(cache, f"{name}-{info['version']}")
        lic = "UNKNOWN"
        for fn in ("LICENSE", "LICENSE.md", "LICENSE.txt"):
            p = os.path.join(d, fn)
            if os.path.exists(p):
                lic = classify(open(p, errors="ignore").read()); break
        yield ("dart", name, info["version"], lic)

def npm():
    out = subprocess.run(["npm", "ls", "--omit=dev", "--all", "--parseable"], cwd=os.path.join(ROOT, "admin"),
                         capture_output=True, text=True).stdout.splitlines()[1:]
    seen = set()
    for d in out:
        try: p = json.load(open(os.path.join(d, "package.json")))
        except OSError: continue
        lic = p.get("license") if isinstance(p.get("license"), str) else "UNKNOWN"
        key = (p["name"], p["version"])
        if key not in seen:
            seen.add(key); yield ("npm", p["name"], p["version"], lic)

flagged = 0
for row in list(dart()) + list(npm()):
    ok = row[3] in ALLOWED
    flagged += 0 if ok else 1
    print("\t".join(row) + ("" if ok else "\tREVIEW"))
print(f"# {flagged} package(s) need review", file=sys.stderr)
