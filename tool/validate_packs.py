"""Validate built-in word packs in assets/packs/.

Usage (from repo root):  python -I tool/validate_packs.py [packs_dir]
Stdlib only. Exit code 0 = all packs valid, 1 = errors found.
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

MIN_WORDS = 60
MAX_WORDS = 100
MAX_WORD_TOKENS = 3
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
ENTRY_KEYS = {"word", "hint", "similar"}
PACK_KEYS = {"id", "name", "emoji", "words"}


def norm(text):
    """Case- and diacritics-insensitive form used for comparisons."""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(stripped.casefold().split())


def check_text(value, label, errors):
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label}: must be a non-empty string")
        return False
    if value != value.strip() or "  " in value:
        errors.append(f"{label}: stray whitespace in {value!r}")
    return True


def validate_pack(path, errors):
    label = path.name
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"{label}: cannot parse JSON ({exc})")
        return None

    if not isinstance(data, dict):
        errors.append(f"{label}: top level must be an object")
        return None
    keys = set(data)
    if keys != PACK_KEYS:
        errors.append(f"{label}: keys must be {sorted(PACK_KEYS)}, got {sorted(keys)}")

    pack_id = data.get("id")
    if check_text(pack_id, f"{label}.id", errors):
        if not ID_RE.match(pack_id):
            errors.append(f"{label}.id: {pack_id!r} must be lowercase kebab-case ASCII")
        if pack_id != path.stem:
            errors.append(f"{label}.id: {pack_id!r} must match file name {path.stem!r}")
    check_text(data.get("name"), f"{label}.name", errors)
    check_text(data.get("emoji"), f"{label}.emoji", errors)

    words = data.get("words")
    if not isinstance(words, list):
        errors.append(f"{label}.words: must be a list")
        return pack_id
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
    return pack_id


def main():
    root = Path(__file__).resolve().parent.parent
    packs_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "assets" / "packs"
    errors = []

    index_path = packs_dir / "index.json"
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"index.json: cannot read ({exc})")
        return 1
    if not isinstance(index, list) or not all(isinstance(x, str) for x in index):
        errors.append("index.json: must be a list of pack id strings")
        index = []
    if len(set(index)) != len(index):
        errors.append("index.json: contains duplicate ids")

    files = sorted(p for p in packs_dir.glob("*.json") if p.name != "index.json")
    ids = set()
    total = 0
    for path in files:
        pack_id = validate_pack(path, errors)
        if pack_id:
            ids.add(pack_id)
        try:
            total += len(json.loads(path.read_text(encoding="utf-8")).get("words", []))
        except (OSError, ValueError, AttributeError):
            pass

    for missing in sorted(set(index) - {p.stem for p in files}):
        errors.append(f"index.json: lists {missing!r} but {missing}.json does not exist")
    for extra in sorted({p.stem for p in files} - set(index)):
        errors.append(f"index.json: does not list existing pack {extra!r}")

    if errors:
        for err in errors:
            print(err)
        print(f"\nFAILED: {len(errors)} error(s)")
        return 1
    print(f"OK: {len(files)} packs, {total} words")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
