#!/bin/bash

set -o errexit
set -o nounset

if [ $# -ne 2 ]; then
    echo "Error: Wrong number of arguments"
    echo "Usage:"
    echo "bash ./add-extra-containerimage.sh /path/to/where/installation-files-were-created containerimage"
    exit 1
fi

if [ ! -d $1 ]; then
  echo "Error: The given argument $1 is not a directory"
  exit 1
fi

if [ ! -d $1/extra_containerimages ]; then
  echo "Error: The extra_containerimages directory is missing"
  exit 1
fi

if ! podman image exists $2; then
  echo Error: containerimage does not exist in local storage. First run \"podman pull $2\"
  exit 1
fi

dir=$(mktemp "--tmpdir=$1/extra_containerimages" -d tmpXXXX)

podman save $2 > "${dir}/image.tar"
echo $2 > "${dir}/name"
