#!/usr/bin/env python3
"""Builds the String Catalogs from tools/translations.txt.

    python tools/build_catalogs.py

Writes:
  VoiceInvoice/Resources/Localizable.xcstrings   (app)
  VoiceInvoiceWidgets/Localizable.xcstrings      (widget extension and controls)
  VoiceInvoice/Resources/InfoPlist.xcstrings     (permission prompts)
  VoiceInvoice/Resources/AppShortcuts.xcstrings  (Siri phrases)
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["fr", "es", "it", "zh-Hans"]
EXTRA_LANGS = ["ar", "hi", "ur"]
LANG_LINE = re.compile(r"^(en|fr|es|it|zh|ar|hi|ur)(?:\.(zero|one|two|few|many|other))?: (.*)$")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def parse(path):
    sections = {"app": [], "widget": [], "infoplist": [], "shortcuts": []}
    current = None
    entry = None
    for raw in open(path, encoding="utf-8").read().split("\n"):
        line = raw.rstrip()
        if line.startswith("#"):
            continue
        if line in ("@app", "@widget", "@infoplist", "@shortcuts"):
            current = line[1:]
            entry = None
            continue
        if not line:
            entry = None
            continue
        match = LANG_LINE.match(line)
        if match and entry is not None:
            lang, plural, value = match.groups()
            entry["values"].setdefault(lang, {})[plural or "value"] = value
            continue
        if line.startswith("@plural "):
            entry = {"key": line[len("@plural "):], "plural": True, "values": {}}
        else:
            entry = {"key": line, "plural": False, "values": {}}
        sections[current].append(entry)
    return sections


def merge_extra(sections, path):
    """Adds the Arabic, Hindi and Urdu lines from translations_extra.txt to the entries with the same key."""
    extra = parse(path)
    for name, entries in extra.items():
        index = {e["key"]: e for e in sections[name]}
        for entry in entries:
            base = index.get(entry["key"])
            if base is None:
                sys.exit(f"translations_extra.txt: '{entry['key']}' is not in section @{name} of translations.txt")
            for lang, data in entry["values"].items():
                base["values"][lang] = data


def build(entries, with_en, require_extra=False):
    strings = {}
    for entry in entries:
        key = entry["key"]
        values = entry["values"]
        localizations = {}
        langs = LANGS_FOR_ENTRY(entry, with_en, require_extra)
        for lang in langs:
            code = "zh-Hans" if lang == "zh" else lang
            data = values.get(lang if lang != "zh-Hans" else "zh")
            if entry["plural"]:
                variations = {}
                for form, value in (data or {}).items():
                    variations[form] = unit(value)
                if "other" not in variations:
                    sys.exit(f"plural '{key}' is missing 'other' for {lang}")
                localizations[code] = {"variations": {"plural": variations}}
            else:
                if not data or "value" not in data:
                    sys.exit(f"'{key}' is missing {lang}")
                localizations[code] = unit(data["value"])
        strings[key] = {"extractionState": "manual", "localizations": localizations}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def LANGS_FOR_ENTRY(entry, with_en, require_extra=False):
    langs = ["fr", "es", "it", "zh"]
    if with_en or entry["plural"]:
        langs = ["en"] + langs
    # Arabic, Hindi and Urdu: required in the app, widget and permission prompts; optional elsewhere
    for lang in EXTRA_LANGS:
        if require_extra or lang in entry["values"]:
            langs.append(lang)
    return langs


def write(path, catalog):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"wrote {path}: {len(catalog['strings'])} strings")


def check_against_sources(entries, source_files):
    corpus = ""
    for pattern in source_files:
        for file in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            corpus += open(file, encoding="utf-8").read()
    missing = [e["key"] for e in entries if "%" not in e["key"] and e["key"] not in corpus]
    for key in missing:
        print(f"  note: '{key}' not found in sources")


def main():
    sections = parse(os.path.join(ROOT, "tools", "translations.txt"))
    merge_extra(sections, os.path.join(ROOT, "tools", "translations_extra.txt"))
    check_against_sources(sections["app"], ["VoiceInvoice/**/*.swift", "Shared/*.swift"])
    check_against_sources(sections["widget"], ["VoiceInvoiceWidgets/*.swift", "Shared/*.swift"])
    write("VoiceInvoice/Resources/Localizable.xcstrings", build(sections["app"], with_en=False, require_extra=True))
    write("VoiceInvoiceWidgets/Localizable.xcstrings", build(sections["widget"], with_en=False, require_extra=True))
    write("VoiceInvoice/Resources/InfoPlist.xcstrings", build(sections["infoplist"], with_en=True, require_extra=True))
    write("VoiceInvoice/Resources/AppShortcuts.xcstrings", build(sections["shortcuts"], with_en=False))


if __name__ == "__main__":
    main()
