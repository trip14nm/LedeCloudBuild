#!/usr/bin/env bash
set -euo pipefail

config_dir=$(cd -- "$(dirname -- "$0")" && pwd)
input=${2:?Supply the file to verify}

case ${1:?Supply config or manifest} in
  config)
    grep -Fxq 'CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m-nand=y' "$input" || {
      echo 'Wrong target in .config. Expected CMCC RAX3000M NAND.' >&2
      exit 1
    }
    packages=$(sed -n 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/p' "$input")
    ;;
  manifest)
    packages=$(awk '{print $1}' "$input")
    ;;
  *) exit 2 ;;
esac

missing=0
while IFS= read -r package; do
  if ! grep -Fxq "$package" <<< "$packages"; then
    echo "Missing package: $package" >&2
    missing=1
  fi
done < "$config_dir/required-packages.txt"

if grep -Exq 'firewall4|miniupnpd-nftables' <<< "$packages"; then
  echo 'Found a firewall4 or nftables UPnP package in the fw3 image.' >&2
  exit 1
fi
exit "$missing"
