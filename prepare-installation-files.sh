#!/bin/bash

set -o errexit
set -o nounset

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

tmpdir=$(mktemp -d /tmp/slurm-container-cluster-installation-filesXXXX)
chmod 700 $tmpdir
mkdir -p $tmpdir/etc_munge
mkdir -p $tmpdir/etc_slurm


# Extra container images is later added with the script add-extra-containerimage.sh
mkdir -p $tmpdir/extra_containerimages

# If SELINUX is enabled let us label the files in the volume
volumeArg=$(selinuxenabled 2> /dev/null && echo :Z || true)

# Create the file munge.key

podman run --rm --volume=${tmpdir}/etc_munge:/etc/munge${volumeArg} localhost/slurm-with-norouter /usr/sbin/create-munge-key

podman unshare chown 0:0 ${tmpdir}/etc_munge/munge.key

podman save localhost/mysql-with-norouter > ${tmpdir}/mysql-with-norouter.tar
podman save localhost/slurm-with-norouter > ${tmpdir}/slurm-with-norouter.tar

podman run --rm --volume=${tmpdir}/etc_slurm:/target${volumeArg} localhost/slurm-with-norouter cp -r /etc/slurm/. /target

chmod 600 ${tmpdir}/etc_slurm/slurmdbd.conf

curl -o ${tmpdir}/norouter --fail -L https://github.com/norouter/norouter/releases/latest/download/norouter-$(uname -s)-$(uname -m)
chmod +x ${tmpdir}/norouter
curl -o ${tmpdir}/sshocker --fail -L https://github.com/AkihiroSuda/sshocker/releases/latest/download/sshocker-$(uname -s)-$(uname -m)
chmod +x ${tmpdir}/sshocker

echo installation_files_dir=${tmpdir}
