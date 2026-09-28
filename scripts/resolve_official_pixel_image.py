#!/usr/bin/env python3
"""Resolve a Pixel factory image from an official Google download page.

The resolver deliberately returns only a Google-hosted URL and the SHA-256
printed in the selected device row. It does not guess builds or use mirrors.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from urllib.parse import urlparse
from urllib.request import Request, urlopen


ALLOWED_PAGE_HOSTS = {"developer.android.com", "developers.google.com"}
ALLOWED_DOWNLOAD_HOSTS = {
    "dl.google.com",
    "storage.googleapis.com",
    "android.googleapis.com",
    "ota.googlezip.net",
}


def validate_page_url(page_url: str) -> str:
    parsed = urlparse(page_url)
    host = (parsed.hostname or "").lower().rstrip(".")
    if parsed.scheme != "https" or host not in ALLOWED_PAGE_HOSTS:
        raise ValueError("page URL must be an official HTTPS Google Android page")
    if not parsed.path or parsed.path == "/":
        raise ValueError("page URL has no document path")
    return page_url


def parse_image_page(page_html: str, device_codename: str) -> tuple[str, str]:
    codename = device_codename.strip().lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", codename):
        raise ValueError("device codename must contain only letters, numbers, _ or -")

    row_match = re.search(
        rf"<tr\b[^>]*\bid=[\"']{re.escape(codename)}[\"'][^>]*>.*?</tr>",
        page_html,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not row_match:
        available = sorted(
            set(
                re.findall(
                    r'<tr\b[^>]*\bid=[\"\']([a-z0-9][a-z0-9_-]*)[\"\']',
                    page_html,
                    flags=re.IGNORECASE,
                )
            )
        )
        if available:
            preview = ", ".join(available[:20])
            if len(available) > 20:
                preview += ", ..."
            raise ValueError(
                f"device codename was not found on the official page: {codename}; "
                f"available row ids include: {preview}"
            )
        raise ValueError(f"device codename was not found on the official page: {codename}; no device rows were found")
    row = html.unescape(row_match.group(0))

    hashes = re.findall(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", row, re.IGNORECASE)
    if len(hashes) != 1:
        raise ValueError(f"expected one SHA-256 in the {codename} device row")
    checksum = hashes[0].lower()

    filenames = re.findall(r"[A-Za-z0-9._-]+\.zip", row)
    if len(filenames) != 1:
        raise ValueError(f"expected one package filename in the {codename} device row")
    filename = filenames[0]

    direct_urls = re.findall(
        r"https://(?:dl\.google\.com|storage\.googleapis\.com|android\.googleapis\.com|ota\.googlezip\.net)/[^\"'<>\s]+\.zip",
        page_html,
        re.IGNORECASE,
    )
    matching = [url for url in direct_urls if url.rsplit("/", 1)[-1] == filename]
    if len(matching) != 1:
        raise ValueError(f"could not resolve one official download URL for {filename}")

    parsed = urlparse(matching[0])
    if (parsed.hostname or "").lower() not in ALLOWED_DOWNLOAD_HOSTS:
        raise ValueError("resolved download host is not approved")
    return matching[0], checksum


def fetch_page(page_url: str) -> str:
    request = Request(
        validate_page_url(page_url),
        headers={"User-Agent": "PixelStockGSI-official-page-resolver/0.1"},
    )
    with urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("page_url")
    parser.add_argument("device_codename")
    args = parser.parse_args()
    try:
        url, checksum = parse_image_page(fetch_page(args.page_url), args.device_codename)
    except (OSError, ValueError) as exc:
        print(f"[-] {exc}", file=sys.stderr)
        return 1
    print(url)
    print(checksum)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
