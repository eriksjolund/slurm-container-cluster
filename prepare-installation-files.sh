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

tmpdir=$(mktemp -d)
chmod 700 $tmpdir
mkdir -p $tmpdir/etc_munge
mkdir -p $tmpdir/etc_slurm

# If SELINUX is enabled let us label the files in the volume
volumeArg=$(selinuxenabled 2> /dev/null && echo :Z || true)

# Create the file munge.key

podman run --rm --volume=${tmpdir}/etc_munge:/etc/munge${volumeArg} localhost/slurm-with-norouter /usr/sbin/create-munge-key

podman unshare chown 0:0 ${tmpdir}/etc_munge/munge.key

podman save localhost/mysql-with-norouter > ${tmpdir}/mysql-with-norouter.tar
podman save localhost/slurm-with-norouter > ${tmpdir}/slurm-with-norouter.tar

podman run --rm --volume=${tmpdir}/etc_slurm:/target${volumeArg} localhost/slurm-with-norouter cp -r /etc/slurm/. /target

sed -i 's/^StorageHost=mysql/StorageHost=localhost/' ${tmpdir}/etc_slurm/slurmdbd.conf

# slurmdbd, slurmctld and slurmd are all running on non-standard ports.
# norouter remaps these port numbers so that they appear to be running on the
# normal port numbers.
# The configuration file /etc/slurm.conf can't be identical for all of slurmdbd, slurmctld and slurmd,
# because the value SlurmctldPort needs to be given a non-standard value when running slurmctld and
# the value SlurmdPort needs to be given a non-standard value when runnng slurmd.
# By removing the normal lines 
#
# SlurmctldPort=6817
# SlurmdPort=6818
#
# from slurm.conf and adding the new line
#
# include adjusting_ports_for_norouter/include_slurm.conf
#
# we can fine-tune the configuration of port-numbers by doing a bind-mount
# so that one of the directories
# 
# ~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmctld
# ~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmdbd 
# ~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmdbd 
#
# is mapped to /etc/slurm/adjusting_ports_for_norouter/

sed -i '/^SlurmctldPort=/d' ${tmpdir}/etc_slurm/slurm.conf
sed -i '/^SlurmdPort=/d' ${tmpdir}/etc_slurm/slurm.conf

sed -i '/^DbdPort=/d' ${tmpdir}/etc_slurm/slurmdbd.conf
echo DbdPort=7819 >> ${tmpdir}/etc_slurm/slurmdbd.conf

# The slurm configuration differs due to the use of 
# ~/.config/slurm-container-cluster/adjusting_ports_for_norouter/
# We need to disable the check that the configuration should be the same
echo DebugFlags=NO_CONF_HASH >> ${tmpdir}/etc_slurm/slurm.conf

echo include adjusting_ports_for_norouter/include_slurm.conf >> ${tmpdir}/etc_slurm/slurm.conf

curl -o ${tmpdir}/norouter --fail -L https://github.com/norouter/norouter/releases/latest/download/norouter-$(uname -s)-$(uname -m)
chmod +x ${tmpdir}/norouter
curl -o ${tmpdir}/sshocker --fail -L https://github.com/AkihiroSuda/sshocker/releases/latest/download/sshocker-$(uname -s)-$(uname -m)
chmod +x ${tmpdir}/sshocker

echo installation_files_dir=${tmpdir}
