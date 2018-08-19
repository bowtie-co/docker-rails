#!/usr/bin/env bash
set -Eeuo pipefail

repo="bowtie/rails"

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
  versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
  for v in \
    {pg,mysql}{/paperclip,/active_storage,} \
  ; do
    dir="$version/$v"
    variant=$(echo ${v//\//\-})

    [ -d "$dir" ] || continue

    dockerfile="$dir/Dockerfile"
    tag="$version-$variant"

    if [ -f $dockerfile ]; then
      docker build -f $dockerfile -t $repo:$tag .
      docker push $repo:$tag
    fi
  done
done
