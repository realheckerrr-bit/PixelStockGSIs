#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq --no-install-recommends \
  android-sdk-libsparse-utils \
  curl \
  e2fsprogs \
  erofs-utils \
  file \
  gzip \
  p7zip-full \
  python3 \
  unzip \
  xz-utils

# Full OTA packages contain payload.bin. Keep the helper version visible in
# the GitHub Release metadata so a build can be reproduced or investigated later.
if ! command -v payload-dumper-go >/dev/null 2>&1; then
  version=$(curl --fail --silent --show-error --location --retry 3 \
    https://api.github.com/repos/ssut/payload-dumper-go/releases/latest \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')
  archive="/tmp/payload-dumper-go.tar.gz"
  curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/ssut/payload-dumper-go/releases/download/${version}/payload-dumper-go_${version}_linux_amd64.tar.gz" \
    -o "$archive"
  tar -xzf "$archive" -C /tmp
  sudo install -m 0755 /tmp/payload-dumper-go /usr/local/bin/payload-dumper-go
  rm -f -- "$archive" /tmp/payload-dumper-go
fi

echo "payload-dumper-go: $(payload-dumper-go --version 2>/dev/null || echo installed)"
