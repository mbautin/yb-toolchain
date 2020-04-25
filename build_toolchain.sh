#!/usr/bin/env bahs

set -euo pipefail

yum install -y flex texinfo help2man gperf bison
ctng_tag=crosstool-ng-1.24.0
git clone https://github.com/crosstool-ng/crosstool-ng --branch "$ctng_tag" -depth 1 "$ctng_tag"
cd "$ctng_tag"
./bootstrap
ctng_prefix=/usr/share/$ctng_tag
./configure --prefix=$ctng_prefix
make
make install

cd ct-ng-config
"$ctng_prefix/bin/ct-ng" build
