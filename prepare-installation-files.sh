#!/bin/bash

set -o errexit
set -o nounset

if [ $# -ne 1 ]; then
    echo "Error: Wrong number of arguments"
    echo "Usage:"
    echo "bash ./prepare-installation-files.sh /path/to/where/empty-directory-to-store-installation-files"
    exit 1
fi

if [ ! -d $1 ]; then
  echo "Error: The given argument $1 is not a directory"
  exit 1
fi

if [ -n "$(ls -A $1)" ]; then
  echo "Error: The directory $1 is not empty"
  exit 1
fi

if ! podman image exists localhost/mysql-with-norouter; then
    echo The container image  localhost/slurm-with-norouter does not exit.
    echo Please build the container first
    exit 1
fi

if ! podman image exists localhost/slurm-with-norouter; then
    echo The container image  localhost/slurm-with-norouter does not exit.
    echo Please build the container first
    exit 1
fi

mkdir -p $1/etc_munge
mkdir -p $1/etc_slurm


# Extra container images is later added with the script add-extra-containerimage.sh
mkdir -p $1/extra_containerimages

# If SELINUX is enabled let us label the files in the volume
volumeArg=$(selinuxenabled 2> /dev/null && echo :Z || true)

# Create the file munge.key

podman run --rm --volume=$1/etc_munge:/etc/munge${volumeArg} localhost/slurm-with-norouter /usr/sbin/create-munge-key

podman unshare chown 0:0 $1/etc_munge/munge.key

podman save localhost/mysql-with-norouter > $1/mysql-with-norouter.tar
podman save localhost/slurm-with-norouter > $1/slurm-with-norouter.tar

podman run --rm --volume=$1/etc_slurm:/target${volumeArg} localhost/slurm-with-norouter cp -r /etc/slurm/. /target

chmod 600 $1/etc_slurm/slurmdbd.conf

curl -o $1/norouter --fail -L https://github.com/norouter/norouter/releases/latest/download/norouter-$(uname -s)-$(uname -m)
chmod +x $1/norouter
curl -o $1/sshocker --fail -L https://github.com/AkihiroSuda/sshocker/releases/latest/download/sshocker-$(uname -s)-$(uname -m)
chmod +x $1/sshocker
