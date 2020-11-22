## Design details

Right now it is unclear if the portmapping and
the files under slurm-container-cluster/adjusting_ports_for_norouter/
are really needed. It is likely that this could be simplified.

The first goal was just to have a proof-of-concept to show that it
is possible to run Slurm in containers with the help of __podman__, __norouter__, __sshfs__ and __sshocker__.
The proof-of-concept also shows that it is possible to run `podman run` in the _sbatch_ scripts.
To be able to do that the technique running Podman in Podman was used
(see also https://stackoverflow.com/questions/64509618/podman-in-podman-similar-to-docker-in-docker)

### Remapping port numbers

`slurmdbd`, `slurmctld` and `slurmd` are all running on non-standard ports.
 `norouter` remaps these port numbers so that they appear to be running on the
 normal port numbers.
 The configuration file _/etc/slurm.conf_ will differ slightly for when running `slurmdbd`, `slurmctld` and `slurmd`,
because the value SlurmctldPort needs to be given a non-standard value when running slurmctld and
the value SlurmdPort needs to be given a non-standard value when runnng slurmd.

Slurm normally complains if the _slurm.conf_ is different. To disable this check this line was added
```
DebugFlags=NO_CONF_HASH
```

The adjustment of port numbers was done by removing the normal lines

```
SlurmctldPort=6817
SlurmdPort=6818
```

from _slurm.conf_ and adding the new line

```
include adjusting_ports_for_norouter/include_slurm.conf
```

so that we can fine-tune the configuration of port-numbers by doing a bind-mount
of one the directories

* _~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmctld_
* _~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmdbd_
* _~/.config/slurm-container-cluster/adjusting_ports_for_norouter/slurmdb_

on to _/etc/slurm/adjusting_ports_for_norouter/_
