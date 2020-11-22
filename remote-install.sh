#!/bin/bash

set -o errexit
set -o nounset

if [ $# -ne 2 ]; then
    echo "Error: Wrong number of arguments"
    echo "Usage:"
    echo "bash ./remote-install.sh /path/to/where/installation-files-were-created username@host"
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

ssh $2 mkdir -p .config/systemd/user \
                .config/slurm-container-cluster/install-norouter \
                .config/slurm-container-cluster/install-sshocker

rsync -e ssh -r adjusting_ports_for_norouter/ \
     $2:.config/slurm-container-cluster/adjusting_ports_for_norouter

# Let's assume we run the same architecture on the remote host.
# We can then copy out the already downloaded executables
# norouter and sshocker.

scp "$1/norouter" \
     $2:.config/slurm-container-cluster/install-norouter/norouter 
scp "$1/sshocker" \
     $2:.config/slurm-container-cluster/install-sshocker/sshocker 

for i in slurm-computenode@.service \
	 slurm-create-datadir.service \
	 slurm-install-norouter.service \
	 slurm-install-sshocker.service ;
do
    scp ./systemd/$i $2:.config/systemd/user
done

ssh $2 systemctl --user daemon-reload

for i in slurm-create-datadir.service \
	 slurm-install-norouter.service \
	 slurm-install-sshocker.service ;
do
    ssh $2 systemctl --user enable --now $i
done

cat "$1/slurm-with-norouter.tar" | ssh $2 podman load localhost/slurm-with-norouter
cat "$1/mysql-with-norouter.tar" | ssh $2 podman load localhost/mysql-with-norouter

cat "$1/etc_munge/munge.key" | ssh $2 podman unshare sh -c '"mkdir -p ~/.config/slurm-container-cluster/etc_munge && cd ~/.config/slurm-container-cluster/etc_munge/ && cat - > munge.key && chmod 700 munge.key && chown -R 993:992 ~/.config/slurm-container-cluster/etc_munge"'

ssh $2 mkdir -p .config/slurm-container-cluster/etc_slurm
rsync -e ssh -r "$1/etc_slurm/" $2:.config/slurm-container-cluster/etc_slurm

ssh $2 podman unshare sh -c '"podman unshare chown 997:997 ~/.config/slurm-container-cluster/etc_slurm/slurmdbd.conf && podman unshare chmod 600 ~/.config/slurm-container-cluster/etc_slurm/slurmdbd.conf"'

# Create a read-only shared image storage for all container images that
# were added with add-extra-containerimage.sh
store=.config/slurm-container-cluster/extra-containerimages
ssh $2 mkdir -p "$store"
shopt -s nullglob
for i in $1/extra_containerimages/tmp*; do
  name=$(cat $i/name)
  if [ -z "$name" ]; then
    echo $i/name is empty
    exit 1
  fi
  cat "$i/image.tar" | ssh $2 podman run -i  --ulimit host --privileged --volume "$store":/store --volume /dev/fuse:/dev/fuse:rw localhost/slurm-with-norouter podman --root /store load $name
done
shopt -u nullglob
