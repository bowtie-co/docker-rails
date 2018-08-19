#!/usr/bin/env bash
set -Eeuo pipefail

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

    pkg_list=""
    tag="$(basename "$(dirname "$dir")")"

    case "$variant" in
      pg*) pkg_list="$pkg_list libpq-dev" ;;
      mysql*) pkg_list="$pkg_list default-libmysqlclient-dev" ;;
    esac

    case "$variant" in
      *paperclip) pkg_list="$pkg_list ghostscript imagemagick libmagic-dev graphviz" ;;
      *active_storage) pkg_list="$pkg_list ghostscript libvips libvips-dev graphviz" ;;
    esac

    pkg_list="$(echo -e "${pkg_list}" | sed -e 's/^[[:space:]]*//')"

    template="template.Dockerfile"

    sed -r \
      -e 's!%%RUBY_IMAGE_TAG%%!'"$version"'!g' \
      -e 's!%%PACKAGE_LIST%%!'"$pkg_list"'!g' \
      "$template" > "$dir/Dockerfile"

    echo "$dir/Dockerfile"
  done
done
