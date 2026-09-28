#!/bin/sh
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache="$here/.build"
work="$cache/download"
inputs="$cache/inputs"
mkdir -p "$work"
mkdir -p "$inputs"

fetch_archive() {
  archive=$1
  url=$2
  expected=$3
  dest="$work/$archive"
  if [ ! -f "$dest" ]; then
    curl --fail --location --retry 3 --output "$dest.tmp" "$url"
    mv "$dest.tmp" "$dest"
  fi
  actual=$(shasum -a 256 "$dest" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    printf 'SHA-256 mismatch for %s: expected %s, got %s\n' "$archive" "$expected" "$actual" >&2
    exit 1
  fi
  printf '%s  %s\n' "$actual" "$archive" >> "$cache/SHA256SUMS"
  printf '%s\n' "$dest"
}

rm -f "$cache/SHA256SUMS"
lm_archive=$(fetch_archive lm.zip https://mirrors.ctan.org/fonts/lm.zip 71c48809cb50fbfe09c8eddaa251398957c7b243acdf69f7f807268f0d42c939)
cmu_archive=$(fetch_archive cm-unicode.zip https://mirrors.ctan.org/fonts/cm-unicode.zip 9631fe99640da97875755db86cbb85fe99bd06526b65f0c42b4df266e1091af0)

extract_member() {
  archive=$1
  suffix=$2
  output=$3
  member=$(unzip -Z1 "$archive" | awk -v suffix="$suffix" 'length($0) >= length(suffix) && substr($0, length($0) - length(suffix) + 1) == suffix { print }')
  if [ "$(printf '%s\n' "$member" | wc -l | tr -d ' ')" -ne 1 ] || [ -z "$member" ]; then
    printf 'Expected exactly one archive member ending in %s\n' "$suffix" >&2
    exit 1
  fi
  unzip -p "$archive" "$member" > "$output"
}

extract_member "$lm_archive" fonts/opentype/public/lm/lmroman12-regular.otf "$inputs/lmroman12-regular.otf"
extract_member "$cmu_archive" fonts/otf/cmunrm.otf "$inputs/cmunrm.otf"
extract_member "$lm_archive" GUST-FONT-LICENSE.TXT "$inputs/GUST-FONT-LICENSE.TXT"
extract_member "$cmu_archive" /doc/OFL.txt "$inputs/OFL.txt"
shasum -a 256 "$inputs/lmroman12-regular.otf" "$inputs/cmunrm.otf" "$inputs/GUST-FONT-LICENSE.TXT" "$inputs/OFL.txt" > "$cache/INPUTS-SHA256SUMS"
printf 'Font inputs and license texts staged in %s\n' "$inputs"
printf 'Verified archive and selected-input digests: %s\n' "$cache"
