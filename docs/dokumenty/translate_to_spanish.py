#!/usr/bin/env python3
"""
Script to translate en.json to es.json (Spanish) for FalcoNest B2B SaaS.
Preserves all placeholder patterns like {message}, {error}, {count}, {name}, etc.
Uses batch translation for efficiency.
"""

import json
import re
import sys
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator
    USE_DEEP_TRANSLATOR = True
except ImportError:
    USE_DEEP_TRANSLATOR = False

# Placeholder pattern: {variable_name}
PLACEHOLDER_PATTERN = re.compile(r'(\{[a-zA-Z0-9_]+\})')
PLACEHOLDER_TOKEN = "@@PH{}@@"
BATCH_SIZE = 30


def extract_placeholders(text: str) -> tuple[list[str], str]:
    """Extract placeholders and replace with tokens. Returns (placeholders, modified_text)."""
    placeholders = []
    def replacer(match):
        idx = len(placeholders)
        placeholders.append(match.group(1))
        return PLACEHOLDER_TOKEN.format(idx)
    modified = PLACEHOLDER_PATTERN.sub(replacer, text)
    return placeholders, modified


def restore_placeholders(text: str, placeholders: list[str]) -> str:
    """Restore placeholders in translated text."""
    for idx, ph in enumerate(placeholders):
        text = text.replace(PLACEHOLDER_TOKEN.format(idx), ph)
    return text


def collect_strings(obj, path: str = "") -> list[tuple[str, str]]:
    """Collect (path, value) for all leaf strings in consistent order."""
    result = []
    if isinstance(obj, dict):
        for k in sorted(obj.keys()):
            result.extend(collect_strings(obj[k], f"{path}.{k}" if path else k))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            result.extend(collect_strings(item, f"{path}[{i}]"))
    elif isinstance(obj, str):
        result.append((path, obj))
    return result


def translate_batch(texts: list[str], translator) -> list[str]:
    """Translate a batch of texts, preserving placeholders in each."""
    prepared = []  # list of (text_for_api, placeholders) or None for empty
    for text in texts:
        if not text or not text.strip():
            prepared.append(None)
            continue
        placeholders, protected = extract_placeholders(text)
        prepared.append((protected, placeholders))
    to_translate = [p[0] if p else "" for p in prepared]
    try:
        translated_raw = translator.translate_batch(to_translate)
    except Exception as e:
        print(f"  Batch failed: {e}. Translating individually...", file=sys.stderr)
        translated_raw = []
        for p in prepared:
            if p:
                try:
                    time.sleep(0.1)
                    translated_raw.append(translator.translate(p[0]))
                except Exception:
                    translated_raw.append(p[0])
            else:
                translated_raw.append("")
    out = []
    for i, p in enumerate(prepared):
        raw = translated_raw[i] if i < len(translated_raw) else (to_translate[i] if p else "")
        if p and p[1]:
            out.append(restore_placeholders(raw, p[1]))
        else:
            out.append(raw if raw else texts[i])
    return out


def main():
    base_dir = Path(__file__).resolve().parent
    en_path = base_dir / "assets" / "translations" / "en.json"
    es_path = base_dir / "assets" / "translations" / "es.json"

    if not en_path.exists():
        print(f"Error: {en_path} not found", file=sys.stderr)
        sys.exit(1)

    print("Loading en.json...", flush=True)
    with open(en_path, "r", encoding="utf-8") as f:
        en_data = json.load(f)

    if not USE_DEEP_TRANSLATOR:
        print("Error: deep-translator required. Run: pip install deep-translator", file=sys.stderr)
        sys.exit(1)

    # Collect all strings (path, value)
    items = collect_strings(en_data)
    total = len(items)
    print(f"Translating {total} strings to Spanish (B2B SaaS)...", flush=True)

    translator = GoogleTranslator(source="en", target="es")
    translated_values = []

    for i in range(0, total, BATCH_SIZE):
        batch = items[i:i + BATCH_SIZE]
        batch_texts = [v for _, v in batch]
        print(f"  Batch {i//BATCH_SIZE + 1}: translating {len(batch)} strings...", flush=True)
        try:
            time.sleep(0.3)  # Rate limit between batches
            batch_translated = translate_batch(batch_texts, translator)
            for j, (path, _) in enumerate(batch):
                translated_values.append((path, batch_translated[j] if j < len(batch_translated) else batch_texts[j]))
        except Exception as e:
            print(f"  Error: {e}. Using original text.", file=sys.stderr)
            for path, v in batch:
                translated_values.append((path, v))

    # Rebuild structure - same DFS order as collect_strings (sorted keys)
    def rebuild(struct, path_parts, idx_ref):
        if isinstance(struct, dict):
            return {k: rebuild(struct[k], path_parts + [k], idx_ref) for k in sorted(struct.keys())}
        elif isinstance(struct, list):
            return [rebuild(item, path_parts + [i], idx_ref) for i, item in enumerate(struct)]
        elif isinstance(struct, str):
            if idx_ref[0] < len(translated_values):
                val = translated_values[idx_ref[0]][1]
                idx_ref[0] += 1
                return val
            return struct
        return struct

    es_data = rebuild(en_data, [], [0])

    print(f"Writing to {es_path}...")
    es_path.parent.mkdir(parents=True, exist_ok=True)
    with open(es_path, "w", encoding="utf-8") as f:
        json.dump(es_data, f, ensure_ascii=False, indent=2)

    print("Validating output JSON...")
    try:
        with open(es_path, "r", encoding="utf-8") as f:
            validated = json.load(f)
        def keys_match(a, b):
            if isinstance(a, dict) and isinstance(b, dict):
                if set(a.keys()) != set(b.keys()):
                    return False
                return all(keys_match(a[k], b[k]) for k in a.keys())
            return True
        if keys_match(en_data, validated):
            print("✓ Structure matches en.json (all keys identical)")
        else:
            print("⚠ Structure mismatch detected", file=sys.stderr)
    except json.JSONDecodeError as e:
        print(f"✗ Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"\nDone! Created: {es_path}")
    print("es.json is valid and ready to use.")


if __name__ == "__main__":
    main()
