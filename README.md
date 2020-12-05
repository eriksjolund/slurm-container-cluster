__Status__: It seems to work, but a `systemctl --user restart` might be needed at startup time (see [Troubleshooting](#troubleshooting)).
Running [Nextflow](https://www.nextflow.io/) on top of _slurm-container-cluster_ also seems to work. (See the [Nextflow pipeline example](examples/nextflow/README.md) where _slurm-container-cluster_ runs a two-node Slurm cluster on a laptop and a desktop).

# slurm-container-cluster

Run a Slurm cluster in containers as a non-root user on multiple hosts, by making use of

* [podman](https://github.com/containers/podman/) for running containers. (Replacing `podman` with `docker` might also work but it is untested)
* [norouter](https://github.com/norouter/norouter) for communication
* [sshocker](https://github.com/AkihiroSuda/sshocker/) for sharing a local folder to the remote computers (reverse sshfs)
* [slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster). The __slurm-container-cluster__ project reuses the basic architecture of the __slurm-docker-cluster__ project but introduces multi-host functionality with the help of __norouter__ and __sshocker__. Another difference is that __slurm-container-cluster__ uses __Systemd__ instead of __Docker Compose__.

Each Slurm software component `slurmd`, `slurmdbd`, `slurmctld` and  `mysql` runs in a separate container.
Multiple `slurmd` containers may be used. The `slurmd` containers act as "compute nodes" in Slurm so it makes sense to have a number of them. If you have ssh access to remote computers, you may run the slurmd compute node containers there too. See also the section [_Boot Fedora CoreOS in live mode from a USB stick_](#boot-fedora-coreos-in-live-mode-from-a-usb-stick)) on how to boot up a computer in live mode to let it become a remote ssh-accessible computer.

## Requirements local computer

* __podman__ version >= 2.1.0

(Installing __podman__ might require root permissions, otherwise no root permissions are needed)

## Requirements remote computers

Using remote computers is optional as everything can be run locally.
If you want some remote computers to act as extra compute nodes
they need to be accessible via ssh and need to have

* __podman__ version >= 2.1.0
* __sshfs__

installed.

(Installing __sshfs__ and __podman__ might require root permissions, otherwise no root permissions are needed)

A tip: The Linux distribution [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/) comes with both __podman__ and __sshfs__ pre-installed.

## Introduction

| Systemd service | Description |
| --              | --          |
| [slurm-computenode@.service](./systemd/slurm-computenode@.service) | Template unit file for Slurm compute nodes running `slurmd` in the container [localhost/slurm](container/slurm-docker-cluster-with-norouter/Dockerfile) |
| [slurm-create-datadir.service](./systemd/slurm-create-datadir.service) | Creates some empty directories under _~/.config/slurm-podman/_ that will be used by the other services |
| [slurm-install-norouter.service](./systemd/install-norouter.service) | Install the executable [norouter](https://github.com/norouter/norouter) to _~/.config/slurm-podman/install-norouter/norouter_ |
| [slurm-install-sshocker.service](./systemd/install-sshocker.service) | Install  the executable [sshocker](https://github.com/AkihiroSuda/sshocker) to _~/.config/slurm-podman/install-sshocker/sshocker_ |
| [slurm-mysql.service](./systemd/slurm-mysql.service) | Runs `mysqld` in the container [localhost/mysql-with-norouter](container/mysql-with-norouter/Dockerfile) |
| [slurm-slurmctld.service](./systemd/slurm-slurmctld.service) | Runs `slurmctld` in the container [localhost/slurm-with-norouter](container/slurm-docker-cluster-with-norouter/Dockerfile) |
| [slurm-slurmdbd.service](./systemd/slurm-slurmdbd.service) | Runs `slurmdbd` in the container [localhost/slurm-with-norouter](container/slurm-docker-cluster-with-norouter/Dockerfile) |

## Installation (no root permission required)

### Prepare the installation files

1. Clone this Git repo

```
$ git clone URL
```

2. cd into the Git repo directory

```
$ cd slurm-container-cluster
```

3. Build the container images

```
podman build -t slurm-container-cluster .
podman build -t mysql-with-norouter container/mysql-with-norouter/
podman image tag localhost/slurm-container-cluster localhost/slurm-with-norouter
```

(the identifier _localhost/slurm-with-norouter_ is used in the systemd service files)

4. Create an empty directory

```
mkdir ~/installation_files
installation_files_dir=~/installation_files
```

(The variable is just used to simplify the instructions in this README.md)

5.

```
bash prepare-installation-files.sh $installation_files_dir
```

6.

Add extra container images to the installation files. These container images can be run by podman
in your sbatch scripts.

```
podman pull docker.io/library/alpine:3.12.1
bash add-extra-containerimage.sh $installation_files_dir docker.io/library/alpine:3.12.1
```

### Adjust SLURM configuration

Before running the scripts _local-install.sh_ and _remote-install.sh_ you might
want to modify the configuration file `$installation_files_dir/slurm/slurm.conf`.
(The default `$installation_files_dir/slurm/slurm.conf` 
defines the cluster as having the compute nodes _c1_ and _c2_)

### Install on local computer

If you want to run any of the slurm-related containers on the local computer, then

1. In the git repo directory run

```
bash ./local-install.sh $installation_files_dir
```

The script _local-install.sh_ should only modify files and directories under these directories

* _~/.config/slurm-container-cluster_ (e.g. mysql datadir, Slurm shared jobdir, log files, `sshocker` exectutable and `norouter` executable)
* _~/.local/share/containers/_ (the default directory where Podman stores its images and containers)
* _~/.config/systemd/user_ (installing all the services _slurm-*.service_)

### Install on remote computers

1. For each remote computer, run `bash ./remote-install.sh $installation_files_dir remoteuser@remotehost` on the local computer. It is expected that SSH keys have been set up so that `ssh remoteuser@remotehost` succeeds without having to type any password.

```
bash ./remote-install.sh $installation_files_dir remoteuser@remotehost
```

### Start mysqld, slurmdbd and slurmctld

On the computer that you would like to have mysqld, slurmdbd and slurmctld running
(i.e. most probably the local computer), run

```
systemctl --user enable --now slurm-mysql.service slurm-slurmdbd.service slurm-slurmctld.service
```

(Advanced tip: If your local computer is not running Linux, you might be able to use one of 
the remote computers instead and only use the local computer for running
`sshocker` and `norouter`. This is currently untested.)

### Start the compute node containers

The default `$installation_files_dir/slurm/slurm.conf` 
defines the cluster as having the compute nodes _c1_ and _c2_.

To start the compute node _c1_ on localhost, run

```
systemctl --user enable --now slurm-computenode@1.service
```

To start the compute node _c2_, run

```
systemctl --user enable --now slurm-computenode@2.service
```

They can both be running on the same computer but also on different computers.
Run the command on the computer where you would like to have the Slurm computenode running.

### Configure and start norouter

In case you have 

* _mysqld_, _slurmdbd_, _slurmctld_ and _c1_ running on localhost
* and _c2_ running on a remote computer accessible with remoteuser@192.0.2.10

you could just copy

1. `cp ./norouter.yaml ~`

2. start norouter with `norouter ~/norouter.yaml`

otherwise you need to modify the file _~/norouter.yaml_ to match your setup.

### Start sshocker to share _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared_ with remote computers

[sshocker](https://github.com/AkihiroSuda/sshocker/) is used for having a local directory accessible on the remote computers.

Assuming the remote computer has the IP address __192.0.2.10__ and the user is __remoteuser__. (Using a hostname instead of IP address is also possible). 
To make it easier to copy-paste from this documentation, let us set two shell variables

```
user=remoteuser
host=192.0.2.10
```

Share the local directory _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared_

```
~/.config/install-sshocker/sshocker -v ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared:/home/$user/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared $user@$host
```
(The command is not returning)

Now both the local _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared_ and the remote  _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared_ should contain the same files.

If you have other remote computers, you need to run __sshocker__ commands for them as well.

### Register the cluster

Register the cluster

```
podman exec -it slurmctld bash -c "sacctmgr --immediate add cluster name=linux"
```
Show cluster status

```
podman exec -it slurmctld bash -c "sinfo"
```

### Run compute jobs

Create a shell script in the directory _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared_

```
vim ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/test.sh
```

with this content

```
#!/bin/sh

echo -n "hostname : "
hostname
sleep 10
```

and make it executable

```
chmod 755 ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/test.sh
```

Submit a compute job

```
podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
```


Example session:

```
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && ls -l test.sh"
-rwxr-xr-x 1 root root 53 Nov 14 13:42 test.sh
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && cat test.sh"
#!/bin/sh

echo -n "hostname : "
hostname
sleep 10

user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 24
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 25
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 26
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 27
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 28
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 29
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 30
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./test.sh"
Submitted batch job 31
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && squeue"
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                26    normal  test.sh     root PD       0:00      1 (Resources)
                27    normal  test.sh     root PD       0:00      1 (Priority)
                28    normal  test.sh     root PD       0:00      1 (Priority)
                29    normal  test.sh     root PD       0:00      1 (Priority)
                30    normal  test.sh     root PD       0:00      1 (Priority)
                31    normal  test.sh     root PD       0:00      1 (Priority)
                24    normal  test.sh     root  R       0:08      1 c1
                25    normal  test.sh     root  R       0:08      1 c2
user@laptop:~$ 
```

When the jobs have finished, run

```
user@laptop:~$ ls -l ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/slurm-*.out 
slurm-24.out
slurm-25.out
slurm-26.out
slurm-27.out
slurm-28.out
slurm-29.out
slurm-30.out
slurm-31.out
user@laptop:~$ cat _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/slurm-*.out
hostname : c1
hostname : c2
hostname : c1
hostname : c2
hostname : c1
hostname : c1
hostname : c2
hostname : c1
user@laptop:~$
```

Here is an example of how to to run a container with podman. The container _docker.io/library/alpine:3.12.1_ was previously added to the installation files with the script  _add-extra-containerimage.sh_)

```
user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && cat podman-example.sh"
#!/bin/sh
podman run --user 0 --cgroups disabled --runtime crun --volume /data:/data:rw --events-backend=file --rm docker.io/library/alpine:3.12.1 cat /etc/os-release

user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./podman-example.sh"
Submitted batch job 32
```

When the job has finished, run

```
user@laptop:~$ ls -l ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/slurm-32.out
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.12.1
PRETTY_NAME="Alpine Linux v3.12"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://bugs.alpinelinux.org/"
```

### Inspecting log files to debug errors

Interesting logs can be seen by running

```
podman logs c1
```

```
podman logs slurmdbd
```

```
podman logs slurmctld
```
```
podman logs mysql
```


(The container must still be running in order for the `podman logs` command to succeed).



## Troubleshooting

### Norouter warnings

At startup time there might be a few warnings for just a short while:

```
me@laptop:~$ ~/.config/slurm-container-cluster/install-norouter/norouter ~/norouter.yaml
laptop: INFO[0000] Ready: 127.0.29.100
laptop: INFO[0000] Ready: 127.0.29.3
laptop: INFO[0000] Ready: 127.0.30.1
laptop: INFO[0000] Ready: 127.0.29.2
laptop: INFO[0000] Ready: 127.0.30.2
laptop: WARN[0002] stderr[slurmctld-norouter(127.0.29.3)]: slurmctld: time="2020-12-05T09:48:29Z" level=error msg="failed to dial to \"127.0.0.1:7817\" (\"tcp\")" error="dial tcp 127.0.0.1:7817: connect: connection refused"
laptop: WARN[0002] stderr[slurmctld-norouter(127.0.29.3)]: slurmctld: time="2020-12-05T09:48:29Z" level=error msg="failed to dial to \"127.0.0.1:7817\" (\"tcp\")" error="dial tcp 127.0.0.1:7817: connect: connection refused"
laptop: WARN[0003] stderr[slurmctld-norouter(127.0.29.3)]: slurmctld: time="2020-12-05T09:48:30Z" level=error msg="failed to dial to \"127.0.0.1:7817\" (\"tcp\")" error="dial tcp 127.0.0.1:7817: connect: connection refused"
```

_slurm-container-cluster_ seems to work though, so they can probably be ignored.

But the warning  _laptop: WARN[0004] error while handling L3 packet                error="write |1: broken pipe"_ seems to be more severe.

```
laptop: WARN[0003] stderr[slurmdbd(127.0.29.2)]: d6ade94bd628: time="2020-12-05T08:50:33Z" level=error msg="failed to dial to \"127.0.0.1:7819\" (\"tcp\")" error="dial tcp 127.0.0.1:7819: connect: connection refused"
laptop: WARN[0003] stderr[slurmdbd(127.0.29.2)]: d6ade94bd628: time="2020-12-05T08:50:33Z" level=error msg="failed to dial to \"127.0.0.1:7819\" (\"tcp\")" error="dial tcp 127.0.0.1:7819: connect: connection refused"
laptop: WARN[0004] error while handling L3 packet                error="write |1: broken pipe"
laptop: WARN[0004] error while handling L3 packet                error="write |1: broken pipe"
laptop: WARN[0004] error while handling L3 packet                error="write |1: broken pipe"
```

For those warnings, it seems that a restart of all the _slurm-*_ services is needed.

### Restarting the services

If you experience problems, try this

1. Stop norouter (by pressing _Ctrl-c_)

2. Restart all services

```
systemctl --user restart slurm-mysql slurm-slurmdbd slurm-slurmctld  slurm-create-datadir
```

```
systemctl --user restart  slurm-computenode@1.service
```

```
systemctl --user restart  slurm-computenode@2.service
```

(Note: the restart command should be run on the computer where the service was once enabled).

3. Run _podman logs_

For the different containers

* mysql
* slurmdbd
* slurmctld
* c1
* c2

run `podman logs containername`, for instance

```
$ podman logs c1
---> Starting the MUNGE Authentication service (munged) ...
-- Waiting for norouter to start. Sleeping 2 seconds ...
-- Waiting for norouter to start. Sleeping 2 seconds ...
-- Waiting for norouter to start. Sleeping 2 seconds ...
-- Waiting for norouter to start. Sleeping 2 seconds ...
```

Except for mysql, the containers should be all waiting for norouter to start.

4. Start norouter

# Using _Fedora CoreOS_ to run compute node containers

The Linux distribution [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/) comes with both __podman__ and __sshfs__ pre-installed. If you have some extra computers that are not in use, you could boot them up with a Fedora CoreOS USB stick to get extra Slurm compute nodes.

## Boot Fedora CoreOS in live mode from a USB stick

### Create a customized Fedora CoreOS iso containing your public SSH key

Assuming your

* public ssh key is located in the file _~/.ssh/id_rsa.pub_
* the command `podman` is installed
* the architecture for the iso is _x86_64_
* your preferred choice of username is _myuser_

then run this command 

```
bash create-fcos-iso-with-ssh-key.sh podman x86_64 stable ~/.ssh/id_rsa.pub myuser
```
to create the customized iso file. The path is written to stdout. The bash script and more documentation is available here

https://github.com/eriksjolund/create-fcos-iso-with-ssh-key

If you would like to have sudo permissions you need choose the username _core_.
