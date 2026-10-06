import hashlib, json, pathlib, sys
root = pathlib.Path(__file__).resolve().parents[1]
expected = json.loads((root / 'scripts/protected-rates-hashes.json').read_text())
changed = [path for path, digest in expected.items() if hashlib.sha256((root / path).read_bytes()).hexdigest() != digest]
if changed:
    print('Protected rates files changed: ' + ', '.join(changed))
    sys.exit(1)
print(f'Protected rates files unchanged ({len(expected)} files).')
