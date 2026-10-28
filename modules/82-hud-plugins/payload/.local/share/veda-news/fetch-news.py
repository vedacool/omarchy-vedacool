#!/usr/bin/env python3
"""Fetch tech/science/space/security headlines for the GN HUD and VEDA panels.

Shared by both desktop plugins (vedacool.gn-hud and vedacool.veda-terminal)
and read by ~/Work/bin/veda-screensaver; it lives in ~/.local/share/veda-news/.

Reads a few public RSS/Atom feeds and writes the newest items to a JSON
cache that the plugin watches. Skips the network if the cache is fresher
than MIN_AGE (pass --force to fetch anyway). A failed or empty fetch never
replaces a good cache, so the panel keeps its last headlines offline.

Usage: fetch-news.py <cache.json> [--force]
"""

import html
import json
import os
import re
import sys
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from datetime import datetime

FEEDS = [
    ("SPACE", "NASA", "https://www.nasa.gov/news-release/feed/"),
    ("SPACE", "ESA", "https://www.esa.int/rssfeed/Our_Activities/Space_Science"),
    ("SCIENCE", "SCIENCEDAILY", "https://www.sciencedaily.com/rss/top/science.xml"),
    ("SCIENCE", "PHYS.ORG", "https://phys.org/rss-feed/"),
    ("TECH", "ARS TECHNICA", "https://feeds.arstechnica.com/arstechnica/index"),
    ("TECH", "THE VERGE", "https://www.theverge.com/rss/index.xml"),
    ("TECH", "HACKER NEWS", "https://hnrss.org/frontpage"),
    ("SECURITY", "BLEEPINGCOMPUTER", "https://www.bleepingcomputer.com/feed/"),
    ("SECURITY", "KREBS", "https://krebsonsecurity.com/feed/"),
    ("SECURITY", "DARK READING", "https://www.darkreading.com/rss.xml"),
]
PER_FEED = 5
MAX_ITEMS = 40
MIN_AGE = 25 * 60
TIMEOUT = 15            # per socket operation
DEADLINE = 30           # whole download of one feed, seconds
MAX_BYTES = 2_000_000   # a real feed is well under 1MB

ATOM = "{http://www.w3.org/2005/Atom}"


def parse_time(text):
    if not text:
        return 0
    text = text.strip()
    try:
        return int(parsedate_to_datetime(text).timestamp())
    except (TypeError, ValueError):
        pass
    try:
        return int(datetime.fromisoformat(text.replace("Z", "+00:00")).timestamp())
    except ValueError:
        return 0


# English only. Feeds that mix languages (NASA posts Spanish releases under a
# "NASA en español" category) are filtered by their category tags first, then
# every title goes through a light language check as a safety net.
FOREIGN_CATEGORY = re.compile(r"espa[nñ]ol|fran[cç]ais|deutsch|portugu[eê]s|italiano", re.I)
FOREIGN_WORDS = {"la", "el", "los", "las", "del", "para", "una", "por", "con", "en", "le", "les",
                 "des", "du", "et", "pour", "une", "und", "der", "die", "das", "mit", "für",
                 "ein", "eine", "uma", "os", "com", "não", "sur", "dans"}
ENGLISH_WORDS = {"the", "a", "an", "of", "to", "in", "for", "and", "on", "with", "is", "are",
                 "from", "by", "at", "as", "new", "how", "why", "its", "this", "after"}
FOREIGN_ACCENTS = set("áíóúñ¿¡ãõçàèêâôûìòäöß")
PUNCT_OK = set("–—‘’“”…·•é")


def looks_english(title):
    if any(ord(c) > 0x024F and c not in PUNCT_OK for c in title):
        return False  # non-Latin script
    if sum(1 for c in title.lower() if c in FOREIGN_ACCENTS) >= 2:
        return False
    words = re.findall(r"[a-zà-ÿ]+", title.lower())
    foreign = sum(1 for w in words if w in FOREIGN_WORDS)
    english = sum(1 for w in words if w in ENGLISH_WORDS)
    return not (foreign >= 2 and foreign > english)


def clean(text):
    """Plain text from a feed field. Unescape first, then strip tags: double-
    encoded feeds (&amp;lt;img&amp;gt;) used to come out as real markup that
    Qt's AutoText would render."""
    text = html.unescape(text or "")
    text = re.sub(r"</?[A-Za-z!][^>]*>?", "", text)
    # A "<" that could still start a tag becomes a lookalike; "3 < 5" stays.
    text = re.sub(r"<(?=[A-Za-z!/])", "‹", text)
    # Whitespace (newlines, tabs) becomes single spaces before the remaining
    # control characters are dropped, so words don't run together.
    text = re.sub(r"\s+", " ", text)
    return "".join(ch for ch in text if ch.isprintable()).strip()


def read_capped(resp):
    """The body, refusing anything over MAX_BYTES or slower than DEADLINE."""
    end = time.monotonic() + DEADLINE
    chunks, size = [], 0
    while True:
        if time.monotonic() > end:
            raise TimeoutError("feed took longer than %ds" % DEADLINE)
        chunk = resp.read(65536)
        if not chunk:
            return b"".join(chunks)
        size += len(chunk)
        if size > MAX_BYTES:
            raise ValueError("feed larger than %d bytes" % MAX_BYTES)
        chunks.append(chunk)


def safe_fromstring(data):
    """Parse feed XML without DTDs/entities. A real RSS/Atom feed needs neither;
    a <!DOCTYPE>/<!ENTITY> is how XXE and billion-laughs entity-expansion DoS get
    in, so refuse them outright — cheaper than a defusedxml dependency, and a
    compromised/MITM'd feed can't make the parser blow up memory/CPU."""
    if b"<!DOCTYPE" in data or b"<!ENTITY" in data:
        raise ValueError("feed declares a DTD/entity; refused")
    return ET.fromstring(data)


def fetch(category, source, url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (gn-hud news panel)"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        root = safe_fromstring(read_capped(resp))

    items = []
    for node in root.iter():
        tag = node.tag
        if tag == "item":  # RSS
            if any(FOREIGN_CATEGORY.search(c.text or "") for c in node.findall("category")):
                continue
            title = node.findtext("title")
            link = node.findtext("link")
            when = node.findtext("pubDate") or node.findtext("{http://purl.org/dc/elements/1.1/}date")
        elif tag == ATOM + "entry":  # Atom
            title = node.findtext(ATOM + "title")
            link_el = node.find(ATOM + "link[@rel='alternate']")
            if link_el is None:
                link_el = node.find(ATOM + "link")
            link = link_el.get("href") if link_el is not None else ""
            when = node.findtext(ATOM + "published") or node.findtext(ATOM + "updated")
        else:
            continue
        title, link = clean(title), (link or "").strip()
        if not title or not link.startswith("https://") or not looks_english(title):
            continue
        items.append({"title": title, "link": link, "source": source,
                      "category": category, "time": parse_time(when)})
        if len(items) >= PER_FEED:
            break
    return items


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cache = sys.argv[1]
    force = "--force" in sys.argv[2:]

    if not force and os.path.exists(cache) and time.time() - os.path.getmtime(cache) < MIN_AGE:
        return 0

    items, failed = [], []
    for category, source, url in FEEDS:
        try:
            items.extend(fetch(category, source, url))
        except Exception as exc:  # one bad feed must not sink the rest
            failed.append(f"{source}: {exc.__class__.__name__}")

    if not items:
        print("no headlines fetched; keeping existing cache", file=sys.stderr)
        return 1

    # Newest first within each category, then interleave the categories so
    # busy feeds don't crowd space news off the panel.
    by_cat = {}
    for item in sorted(items, key=lambda i: i["time"], reverse=True):
        by_cat.setdefault(item["category"], []).append(item)
    mixed = []
    while any(by_cat.values()) and len(mixed) < MAX_ITEMS:
        for cat in ("SPACE", "SCIENCE", "TECH", "SECURITY"):
            if by_cat.get(cat):
                mixed.append(by_cat[cat].pop(0))
    data = {"fetched": int(time.time()), "failed": failed, "items": mixed[:MAX_ITEMS]}

    os.makedirs(os.path.dirname(cache), exist_ok=True)
    # A unique temp file in the same directory, then an atomic rename.
    fd, tmp = tempfile.mkstemp(prefix=".news-", suffix=".tmp", dir=os.path.dirname(cache))
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh)
        os.chmod(tmp, 0o644)
        os.replace(tmp, cache)
    except BaseException:
        os.unlink(tmp)
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main())
