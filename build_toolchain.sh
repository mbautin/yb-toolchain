#!/usr/bin/env bash

set -euo pipefail

readonly CTNG_GIT_URL=https://github.com/crosstool-ng/crosstool-ng
readonly CTNG_VERSION=1.24.0

if [[ -z ${GITHUB_TOKEN:-} ]]; then
  echo "GITHUB_TOKEN is not set, will not be able to upload a release" >&2
fi

readonly yb_toolchain_repo_dir=$PWD
if [[ ! -d $yb_toolchain_repo_dir/ct-ng-config ]]; then
  echo "Running in the wrong directory" >&2
  exit 1
fi

readonly git_sha1=$( git rev-parse HEAD )
echo "SHA1: $git_sha1"

user=$USER
switch_user=false
if [[ $USER == "root" ]]; then
  user=yugabyteci
  switch_user=true
fi

if "$switch_user"; then
  ( set -x; chown -R "$user" "$yb_toolchain_repo_dir" )
fi 

( set -x; sudo yum install -y flex texinfo help2man gperf bison )

ctng_tag=crosstool-ng-$CTNG_VERSION
ctng_checkout_parent=$yb_toolchain_repo_dir/build
ctng_prefix=/usr/share/$ctng_tag

if [[ ! -d $ctng_prefix ]]; then
  ( set -x; mkdir -p "$ctng_checkout_parent" )
  ctng_checkout_dir=$ctng_checkout_parent/$ctng_tag
  if [[ ! -d $ctng_checkout_dir ]]; then
    ( set -x; git clone "$CTNG_GIT_URL" --branch "$ctng_tag" --depth 1 "$ctng_checkout_dir" )
  fi
  (
    set -x
    cd "$ctng_checkout_dir"
    ./bootstrap
    ./configure --prefix=$ctng_prefix
    make
    sudo make install
  )
fi

cd "$yb_toolchain_repo_dir/ct-ng-config"
tag=v$( date +%Y%m%d%H%M%S )-${git_sha1:0:10}

toolchain_parent_dir=/opt/yb-build/toolchain
if [[ ! -d $toolchain_parent_dir ]]; then
  mkdir -p "$toolchain_parent_dir"
  chmod 777 "$toolchain_parent_dir"
fi
archive_dir_name=yb-toolchain-$tag
export CT_PREFIX_DIR=$toolchain_parent_dir/$archive_dir_name

sudo_cmd=""
if "$switch_user"; then
  sudo_cmd="sudo -u $user -E"
fi

if [[ ${YB_TOOLCHAIN_ONLY_TEST_UPLOAD:-} == "1" ]]; then
  mkdir -p "$CT_PREFIX_DIR"
  touch "$CT_PREFIX_DIR/hello_world.txt"
else
  # Hide time output with a rotating character, e.g.
  # [63:39] /

  $sudo_cmd "$ctng_prefix/bin/ct-ng" build 2>&1 | grep -E -v '^\[[0-9]{2}:[0-9]{3}\] [/\\-|]$'
fi

archive_tarball_name=$archive_dir_name.tar.gz
archive_tarball_path=$toolchain_parent_dir/$archive_tarball_name
cd "$toolchain_parent_dir"
tar -cvzf "$archive_tarball_name" "$archive_dir_name"

if [[ -n ${GITHUB_TOKEN:-} ]]; then
  cd "$yb_toolchain_repo_dir"
  (
    set -x
    # TODO: also add sha256 checksum in a separate file
    hub release create "$tag" -m "Release $tag" \
      -a "$archive_tarball_path"
  )
else
  echo "GITHUB_TOKEN is not set, skipping archive upload" >&2
fi
