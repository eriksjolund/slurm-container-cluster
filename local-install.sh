#!/bin/bash

set -o errexit
set -o nounset

if [ $# -ne 1 ]; then
    echo "Error: Wrong number of arguments"
    echo "Usage:"
    echo "bash ./local-install.sh /path/to/where/installation-files-were-created"
    exit 1
fi

if [ ! -d $1 ]; then
  echo "Error: The given argument $1 is not a directory"
  exit 1
fi

for i in etc_munge/munge.key \
         mysql-with-norouter.tar \
         norouter \
         slurm-with-norouter.tar \
         etc_slurm/slurm.conf \
         etc_slurm/slurmdbd.conf \
         sshocker ; do
  if [ ! -f $1/$i ]; then
    echo "Error: The directory $1 does not contain $i"
    exit 1
  fi
done

mkdir -p ~/.config/slurm-container-cluster
cp -r ./adjusting_ports_for_norouter -t ~/.config/slurm-container-cluster/

mkdir -p ~/.config/slurm-container-cluster/etc_slurm
cp -r "$1/etc_slurm/." ~/.config/slurm-container-cluster/etc_slurm
podman unshare chown 992:991 ~/.config/slurm-container-cluster/etc_slurm/slurmdbd.conf
podman unshare chmod 600 ~/.config/slurm-container-cluster/etc_slurm/slurmdbd.conf

mkdir -p ~/.config/systemd/user

servicelist="slurm-computenode@.service \
	 slurm-create-datadir.service \
	 slurm-install-norouter.service \
	 slurm-install-sshocker.service \
	 slurm-mysql.service \
	 slurm-slurmctld.service \
	 slurm-slurmdbd.service"

for i in $servicelist ;
do
  cp ./systemd/$i ~/.config/systemd/user
done

systemctl --user daemon-reload

mkdir -p ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared

# The slurm-install-norouter.service will automatically download norouter
# if it is not found here 
# ~/.config/slurm-container-cluster/install-norouter
# We copy it in advance to avoid some downloading.
# It's the same situation for slurm-install-sshocker.service 

mkdir -p ~/.config/slurm-container-cluster/install-norouter
mkdir -p ~/.config/slurm-container-cluster/install-sshocker
cp "$1/norouter" ~/.config/slurm-container-cluster/install-norouter
cp "$1/sshocker" ~/.config/slurm-container-cluster/install-sshocker

cat "$1/slurm-with-norouter.tar" | podman load localhost/slurm-with-norouter
cat "$1/mysql-with-norouter.tar" | podman load localhost/mysql-with-norouter

# Create a read-only shared image storage for all container images that
# were added with add-extra-containerimage.sh
store=~/.config/slurm-container-cluster/extra-containerimages
mkdir -p "$store"
shopt -s nullglob
for i in $1/extra_containerimages/tmp*; do
  name=$(cat $i/name)
  if [ -z "$name" ]; then
    echo $i/name is empty
    exit 1
  fi
  cat "$i/image.tar" | podman run -i  --ulimit host --privileged --volume "$store":/store --volume /dev/fuse:/dev/fuse:rw localhost/slurm-with-norouter podman --root /store load $name
done
shopt -u nullglob

# Install munge.key
cat "$1/etc_munge/munge.key" | podman unshare sh -c "mkdir -p ~/.config/slurm-container-cluster/etc_munge/ && cd ~/.config/slurm-container-cluster/etc_munge/ && cat - > munge.key && chmod 700 munge.key && chown 993:992 -R ~/.config/slurm-container-cluster/etc_munge"

systemctl --user enable --now slurm-create-datadir.service \
                              slurm-install-norouter.service \
                              slurm-install-sshocker.service
