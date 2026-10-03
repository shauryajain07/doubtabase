#!/usr/bin/env python3
"""Create the one-item Sparkle feed published with each GitHub release."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
import xml.etree.ElementTree as ET


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--signature", required=True)
    args = parser.parse_args()

    repository = args.repository.rstrip("/")
    archive_name = args.archive.name
    archive_url = f"{repository}/releases/download/{args.tag}/{archive_name}"

    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "Doubtabase updates"
    ET.SubElement(channel, "link").text = repository
    ET.SubElement(channel, "description").text = "Doubtabase for Mac releases"
    ET.SubElement(channel, "language").text = "en"

    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Doubtabase {args.version}"
    ET.SubElement(item, "link").text = f"{repository}/releases/tag/{args.tag}"
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc), usegmt=True)
    ET.SubElement(item, f"{{{SPARKLE_NS}}}version").text = args.build
    ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString").text = args.version

    ET.SubElement(
        item,
        "enclosure",
        {
            "url": archive_url,
            f"{{{SPARKLE_NS}}}edSignature": args.signature,
            "length": str(args.archive.stat().st_size),
            "type": "application/octet-stream",
        },
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(rss).write(args.output, encoding="utf-8", xml_declaration=True)
    with args.output.open("ab") as feed:
        feed.write(b"\n")


if __name__ == "__main__":
    main()
