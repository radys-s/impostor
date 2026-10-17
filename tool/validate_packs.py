"""Validate word packs: bundled (assets/packs/) and store (store/packs/ + store/catalog.json).

Usage (from repo root):  python -I tool/validate_packs.py [repo_root]
Stdlib only. Exit code 0 = everything valid, 1 = errors found.
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

MIN_WORDS = 60
MAX_WORDS = 100
MAX_WORD_TOKENS = 3
AUDIENCES = ("family", "friends", "adult")  # order = order in index.json
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
ENTRY_KEYS = {"word", "hint", "similar"}
PACK_KEYS = {"id", "name", "emoji", "audience", "words"}
CATALOG_PACK_KEYS = {"id", "type", "name", "emoji", "description", "audience", "path", "words"}
STORE_PACK_PREFIX = "pack-"


def norm(text):
    """Case- and diacritics-insensitive form used for comparisons."""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(stripped.casefold().split())


def load_json(path, errors, label):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"{label}: cannot read JSON ({exc})")
        return None


def check_text(value, label, errors):
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label}: must be a non-empty string")
        return False
    if value != value.strip() or "  " in value:
        errors.append(f"{label}: stray whitespace in {value!r}")
    return True


def validate_pack(path, errors, label):
    """Validate one pack file. Returns the parsed pack (dict) or None."""
    data = load_json(path, errors, label)
    if data is None:
        return None
    if not isinstance(data, dict):
        errors.append(f"{label}: top level must be an object")
        return None
    if set(data) != PACK_KEYS:
        errors.append(f"{label}: keys must be {sorted(PACK_KEYS)}, got {sorted(data)}")

    pack_id = data.get("id")
    if check_text(pack_id, f"{label}.id", errors):
        if not ID_RE.match(pack_id):
            errors.append(f"{label}.id: {pack_id!r} must be lowercase kebab-case ASCII")
        if pack_id != path.stem:
            errors.append(f"{label}.id: {pack_id!r} must match file name {path.stem!r}")
    check_text(data.get("name"), f"{label}.name", errors)
    check_text(data.get("emoji"), f"{label}.emoji", errors)
    if data.get("audience") not in AUDIENCES:
        errors.append(f"{label}.audience: {data.get('audience')!r} must be one of {list(AUDIENCES)}")

    words = data.get("words")
    if not isinstance(words, list):
        errors.append(f"{label}.words: must be a list")
        return data
    if not MIN_WORDS <= len(words) <= MAX_WORDS:
        errors.append(f"{label}.words: has {len(words)} entries, expected {MIN_WORDS}-{MAX_WORDS}")

    seen = {}
    for i, entry in enumerate(words):
        where = f"{label}.words[{i}]"
        if not isinstance(entry, dict):
            errors.append(f"{where}: must be an object")
            continue
        if set(entry) != ENTRY_KEYS:
            errors.append(f"{where}: keys must be {sorted(ENTRY_KEYS)}, got {sorted(entry)}")
        ok = all(check_text(entry.get(k), f"{where}.{k}", errors) for k in ("word", "hint", "similar"))
        if not ok:
            continue
        word, hint, similar = entry["word"], entry["hint"], entry["similar"]
        where = f"{where} {word!r}"
        nw, nh, ns = norm(word), norm(hint), norm(similar)

        if len(word.split()) > MAX_WORD_TOKENS:
            errors.append(f"{where}: word has more than {MAX_WORD_TOKENS} words")
        if word[0] != word[0].upper():
            errors.append(f"{where}: word must start with a capital letter")
        if len(hint.split()) != 1:
            errors.append(f"{where}: hint {hint!r} must be a single word")
        if nh == nw:
            errors.append(f"{where}: hint equals word")
        elif nh in nw or nw in nh:
            errors.append(f"{where}: hint {hint!r} overlaps word")
        if ns == nw:
            errors.append(f"{where}: similar equals word")

        if nw in seen:
            errors.append(f"{where}: duplicate of entry {seen[nw]}")
        else:
            seen[nw] = i
    return data


def validate_bundled(packs_dir, errors):
    """Validate assets/packs/. Returns (packs by id, word count)."""
    packs = {}
    total = 0
    for path in sorted(p for p in packs_dir.glob("*.json") if p.name != "index.json"):
        data = validate_pack(path, errors, f"assets/packs/{path.name}")
        if data is not None:
            packs[path.stem] = data
            total += len(data.get("words") or [])

    index = load_json(packs_dir / "index.json", errors, "assets/packs/index.json")
    if index is None:
        return packs, total
    if not isinstance(index, list) or not all(isinstance(x, str) for x in index):
        errors.append("assets/packs/index.json: must be a list of pack id strings")
        return packs, total
    if len(set(index)) != len(index):
        errors.append("assets/packs/index.json: contains duplicate ids")
    for missing in sorted(set(index) - set(packs)):
        errors.append(f"assets/packs/index.json: lists {missing!r} but {missing}.json does not exist")
    for extra in sorted(set(packs) - set(index)):
        errors.append(f"assets/packs/index.json: does not list existing pack {extra!r}")

    rank = {a: i for i, a in enumerate(AUDIENCES)}
    last = 0
    for pack_id in index:
        audience = (packs.get(pack_id) or {}).get("audience")
        if audience not in rank:
            continue
        if rank[audience] < last:
            errors.append(f"assets/packs/index.json: {pack_id!r} ({audience}) is out of order; "
                          f"keep {' -> '.join(AUDIENCES)}")
        last = max(last, rank[audience])
    return packs, total


def validate_store(store_dir, root, bundled_ids, errors):
    """Validate store/packs/ and store/catalog.json. Returns (pack count, word count)."""
    packs = {}
    total = 0
    for path in sorted((store_dir / "packs").glob("*.json")):
        data = validate_pack(path, errors, f"store/packs/{path.name}")
        if data is not None:
            packs[path.stem] = data
            total += len(data.get("words") or [])
            if path.stem in bundled_ids:
                errors.append(f"store/packs/{path.name}: id collides with a bundled pack")

    catalog = load_json(store_dir / "catalog.json", errors, "store/catalog.json")
    if catalog is None:
        return len(packs), total
    if not isinstance(catalog, dict) or not isinstance(catalog.get("plugins"), list):
        errors.append("store/catalog.json: must be an object with a 'plugins' list")
        return len(packs), total
    version = catalog.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        errors.append("store/catalog.json: 'version' must be a positive integer")

    seen_ids = set()
    listed_files = set()
    for i, plugin in enumerate(catalog["plugins"]):
        where = f"store/catalog.json plugins[{i}]"
        if not isinstance(plugin, dict):
            errors.append(f"{where}: must be an object")
            continue
        plugin_id = plugin.get("id")
        if check_text(plugin_id, f"{where}.id", errors):
            where = f"{where} {plugin_id!r}"
            if plugin_id in seen_ids:
                errors.append(f"{where}: duplicate plugin id")
            seen_ids.add(plugin_id)
        check_text(plugin.get("type"), f"{where}.type", errors)
        check_text(plugin.get("name"), f"{where}.name", errors)
        if plugin.get("type") != "pack":
            continue  # feature plugins are maintained by the app session

        missing = CATALOG_PACK_KEYS - set(plugin)
        if missing:
            errors.append(f"{where}: missing keys {sorted(missing)}")
        check_text(plugin.get("emoji"), f"{where}.emoji", errors)
        check_text(plugin.get("description"), f"{where}.description", errors)
        rel = plugin.get("path")
        if not check_text(rel, f"{where}.path", errors):
            continue
        file_path = (root / rel).resolve()
        if file_path.parent != (store_dir / "packs").resolve() or file_path.suffix != ".json":
            errors.append(f"{where}.path: {rel!r} must point to store/packs/<id>.json")
            continue
        pack = packs.get(file_path.stem)
        if pack is None:
            errors.append(f"{where}.path: {rel!r} does not exist or is invalid")
            continue
        listed_files.add(file_path.stem)
        if plugin_id != STORE_PACK_PREFIX + file_path.stem:
            errors.append(f"{where}: id must be {STORE_PACK_PREFIX + file_path.stem!r}")
        if plugin.get("words") != len(pack.get("words") or []):
            errors.append(f"{where}.words: {plugin.get('words')!r} != {len(pack.get('words') or [])} in file")
        for key in ("audience", "name", "emoji"):
            if plugin.get(key) != pack.get(key):
                errors.append(f"{where}.{key}: {plugin.get(key)!r} != {pack.get(key)!r} in file")

    for stem in sorted(set(packs) - listed_files):
        errors.append(f"store/packs/{stem}.json: not listed in store/catalog.json")
    return len(packs), total


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    errors = []

    bundled, bundled_words = validate_bundled(root / "assets" / "packs", errors)
    store_dir = root / "store"
    if store_dir.is_dir():
        store_count, store_words = validate_store(store_dir, root, set(bundled), errors)
    else:
        store_count, store_words = 0, 0

    if errors:
        for err in errors:
            print(err)
        print(f"\nFAILED: {len(errors)} error(s)")
        return 1
    print(f"OK: {len(bundled)} bundled packs ({bundled_words} words), "
          f"{store_count} store packs ({store_words} words)")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
