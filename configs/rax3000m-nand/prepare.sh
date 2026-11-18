#!/usr/bin/env bash
set -euo pipefail

config_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source_dir=${1:?Supply the LEDE source directory}

fetch_source() {
  local destination=$1 url=$2 revision=$3

  if [[ ! -d "$destination/.git" ]]; then
    git init -q "$destination"
    git -C "$destination" remote add origin "$url"
  fi
  if [[ $(git -C "$destination" rev-parse --verify HEAD 2>/dev/null || true) != "$revision" ]]; then
    git -C "$destination" fetch -q --depth=1 "$url" "$revision"
    git -C "$destination" checkout -q --detach FETCH_HEAD
  fi
  git -C "$destination" submodule update --init --recursive --depth=1
}

feed_jobs=()
while read -r name url revision; do
  if [[ "$name" = lede ]]; then
    fetch_source "$source_dir" "$url" "$revision"
    cd -- "$source_dir"
    mkdir -p feeds
    : > feeds.conf
  elif [[ "$name" = turboacc ]]; then
    fetch_source "extra-sources/$name" "$url" "$revision" &
    feed_jobs+=("$!")
  else
    echo "src-git $name $url^$revision" >> feeds.conf
    fetch_source "feeds/$name" "$url" "$revision" &
    feed_jobs+=("$!")
  fi
done < "$config_dir/sources.lock"

for pid in "${feed_jobs[@]}"; do
  wait "$pid"
done

# The 25.12 LuCI feed omits Turbo ACC. Import just its FW3-compatible app.
cp -a extra-sources/turboacc/applications/luci-app-turboacc feeds/luci/applications/

# OpenClash looks for its Meta core at this path when small-flash mode is off.
mkdir -p files/etc/openclash/core
ln -sfn /usr/libexec/mihomo files/etc/openclash/core/clash_meta

./scripts/feeds update -a
./scripts/feeds install -a
