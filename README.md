# slurm-container-cluster

Run a Slurm cluster in containers as a non-root user on multiple hosts, by making use of

* [podman](https://github.com/containers/podman/) for running containers. (Replacing `podman` with `docker` might also work but it is untested)
* [norouter](https://github.com/norouter/norouter) for communication
* [sshocker](https://github.com/AkihiroSuda/sshocker/) for sharing a local folder to the remote computers (reverse sshfs)
* [slurm-docker-cluster](https://github.com/giovtorres/slurm-docker-cluster) that provides the base image for the [Dockerfile](./container/slurm-docker-cluster-with-norouter/Dockerfile) that is used to build the container image _localhost/slurm_. The __slurm-container-cluster__ project reuses the basic architecture of the __slurm-docker-cluster__ project but introduces multi-host functionality with the help of __norouter__ and __sshocker__. Another difference is that __slurm-container-cluster__ uses __Systemd__ instead of __Docker Compose__.

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

4. 

```
bash prepare-installation-files.sh
```

A temporary directory will be created that is then filled with installation files.
The path of the temporary directory is written to stdout in the end of the script.
(e.g. installation_files_dir=_/tmp/tmp.WKve6PeZgi_)

5. 

Set the shell variable `installation_files_dir` to the directory path from the previous step,
by copy-pasting the output and run it in the terminal

```
installation_files_dir=/tmp/tmp.WKve6PeZgi
```

(The variable is just used to simplify the instructions in this README.md)


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

echo -n "hostname : "
podman run --user 0 --cgroups disabled --runtime crun --volume /data:/data:rw --events-backend=file --rm docker.io/library/alpine cat /etc/os-release

sleep 3

user@laptop:~$ podman exec -it slurmctld bash -c "cd /data/sshocker_shared && sbatch ./podman-example"
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
