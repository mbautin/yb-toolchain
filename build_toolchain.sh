#!/usr/bin/env bash

set -euo pipefail -x

yb_toolchain_repo_dir=$PWD
if [[ ! -d $yb_toolchain_repo_dir/ct-ng-config ]]; then
  echo "Running in the wrong directory" >&2
  exit 1
fi

chown -R yugabyteci "$yb_toolchain_repo_dir"

yum install -y flex texinfo help2man gperf bison
ctng_tag=crosstool-ng-1.24.0
git clone https://github.com/crosstool-ng/crosstool-ng --branch "$ctng_tag" --depth 1 "$ctng_tag"
cd "$ctng_tag"
./bootstrap
ctng_prefix=/usr/share/$ctng_tag
./configure --prefix=$ctng_prefix
make
make install

cd "$yb_toolchain_repo_dir/ct-ng-config"
version=$( date +%Y%m%d%H%M%S )
export CT_PREFIX_DIR=/opt/yb-build/x-tools/yb-x-tools-$version
sudo -u yugabyteci -E "$ctng_prefix/bin/ct-ng" build
