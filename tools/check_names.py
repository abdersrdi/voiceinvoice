#!/usr/bin/env python3
"""Checks candidate app names against the public App Store search and DNS.

    python tools/check_names.py SaySeal Voxstamp ...

For each name it lists existing apps whose title is the same or very similar. It cannot check
trademarks: do that separately (USPTO, EUIPO, WIPO) before committing to a name.
"""
import difflib
import json
import socket
import sys
import urllib.parse
import urllib.request

COUNTRIES = ["us", "gb", "fr", "es", "it"]


def search(term, country):
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"term": term, "entity": "software", "country": country, "limit": 50}
    )
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            return json.load(response).get("results", [])
    except Exception as error:  # network hiccups should not hide other results
        return [{"trackName": f"(search failed: {error})", "sellerName": ""}]


def normalize(text):
    return "".join(ch for ch in text.lower() if ch.isalnum())


def similar(a, b):
    a, b = normalize(a), normalize(b)
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    ratio = difflib.SequenceMatcher(None, a, b).ratio()
    # a title that starts with, or contains, the whole candidate counts as close
    if a in b or b in a:
        ratio = max(ratio, 0.85)
    return ratio


def domain_taken(name):
    host = normalize(name) + ".com"
    try:
        socket.gethostbyname(host)
        return True
    except socket.gaierror:
        return False


def main():
    names = sys.argv[1:]
    for name in names:
        hits = {}
        for country in COUNTRIES:
            for app in search(name, country):
                title = app.get("trackName", "")
                score = similar(name, title.split(":")[0].split(" - ")[0].split(" – ")[0])
                if score >= 0.78:
                    hits[title] = (round(score, 2), app.get("sellerName", ""), country)
        verdict = "CLEAR" if not hits else "CONFLICT"
        domain = "taken" if domain_taken(name) else "free?"
        print(f"\n{name}: {verdict}   (.com {domain})")
        for title, (score, seller, country) in sorted(hits.items(), key=lambda kv: -kv[1][0])[:5]:
            print(f"   {score:.2f}  {title}  [{seller}, {country}]")


if __name__ == "__main__":
    main()
