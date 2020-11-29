# nextflow BLAST pipeline with slurm-container-cluster

Status: This is work in progress. 

To run the [nextflow BLAST pipeline example](https://www.nextflow.io/example3.html)


1. Follow the installation instructions 1,2,3 in main [README.md](../../README.md)

2. Build the container image that we will be used for running Nextflow.
Tag it with the name _localhost/slurm-with-norouter_ so that it will be the container image used by the systemd services.

```
podman build -t nextflow-slurm examples/nextflow
podman image tag nextflow-slurm localhost/slurm-with-norouter
```

3. Follow the rest of installation instructions in main [README.md](../../README.md), 
but at point number 6 run 

```
podman pull docker.io/nextflow/examples
bash add-extra-containerimage.sh $installation_files_dir docker.io/nextflow/examples
```

4. Start a Bash shell in the _slurmctld_ container

```
podman exec -ti slurmctld /bin/bash
```

5. Create a home directory in a directory that is shared between _slurmctld_ container and the slurm compute node containers.

```
mkdir /data/sshocker_shared/nextflowhome
export HOME=/data/sshocker_shared/nextflowhome
cd $HOME
```

6. Create a Nextflow configuration file

```
mkdir $HOME/.nextflow
vi $HOME/.nextflow/config
```

with this file content

```
process.executor = 'slurm'
podman {
    enabled = true
    temp = 'auto'
   runOptions = '--ulimit host --security-opt label=disable --cgroups disabled --runtime crun --volume /data:/data:rw --events-backend=file '
}
```

7. This is just a sketch. More testing is needed to verify that it actually works.

Try something like

```
nextflow run blast-example -with-podman 
```

or


```
git clone https://github.com/nextflow-io/blast-example.git
nextflow run ./blast-example -with-podman 
```

The command-line options  _--chunkSize_ and _-qs_ looks interesting ...

```
git clone https://github.com/nextflow-io/blast-example.git
nextflow run ./blast-example -qs 4 -with-podman --chunkSize 8
```
