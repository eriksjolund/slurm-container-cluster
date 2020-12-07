# Nextflow blast-example pipeline with slurm-container-cluster

To run the [Nextflow blast-example pipeline](https://www.nextflow.io/example3.html)

1. Follow the installation instruction steps 1, 2 and 3 in the main [README.md](../../README.md)

2. Build the container image that we will be used for running Nextflow.
Tag it with the name _localhost/slurm-with-norouter_ so that it will be the container image used by the systemd services.

```
podman build -t nextflow-slurm examples/nextflow
podman image tag nextflow-slurm localhost/slurm-with-norouter
```

3. Follow the rest of the installation instructions in the main [README.md](../../README.md),
but at step number 6 run

```
podman pull docker.io/nextflow/examples
bash add-extra-containerimage.sh $installation_files_dir docker.io/nextflow/examples
```

4. Start a Bash shell in the _slurmctld_ container

```
podman exec -ti slurmctld /bin/bash
```

5. Create a home directory in a directory that is shared between the _slurmctld_ container and the slurm compute node containers.

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
    runOptions = '--ulimit host --security-opt label=disable --cgroups disabled --runtime crun --volume /data:/data:rw --events-backend=file'
}
```

7. Run the _blast-example_

```
nextflow run blast-example -qs 12 -with-podman --chunkSize 3
```

### Result of the test

It worked!

```
[root@slurmctld ~]# nextflow run blast-example -qs 12 -with-podman --chunkSize 3
N E X T F L O W  ~  version 20.10.0
Pulling nextflow-io/blast-example ...
downloaded from https://github.com/nextflow-io/blast-example.git
Launching `nextflow-io/blast-example` [irreverent_bernard] - revision: 25922a0ae6 [master]
executor >  slurm (4)
[b9/51bc58] process > blast (2)   [100%] 2 of 2 ✔
[fb/34a244] process > extract (2) [100%] 2 of 2 ✔
matching sequences:
```
(Output omitted for brevity)

Both of the Slurm compute nodes (_c1_ and _c2_) have been used for running the compute jobs.

Run `podman logs c1` on the laptop

```
me@laptop$ podman logs c1 |grep "Launching batch job 14"
slurmd: Launching batch job 14 for UID 0
me@laptop$ podman logs c1 |grep "Launching batch job 15"
me@laptop$ podman logs c1 |grep "Launching batch job 16"
slurmd: Launching batch job 16 for UID 0
me@laptop$ podman logs c1 |grep "Launching batch job 17"
me@laptop$
```

Run `podman logs c2` on the remote desktop

```
[user@desktop ~]$ podman logs c2| grep "Launching batch job 15"
slurmd: Launching batch job 15 for UID 0
[user@desktop ~]$ podman logs c2| grep "Launching batch job 14"
[user@desktop ~]$ podman logs c2| grep "Launching batch job 16"
[user@desktop ~]$ podman logs c2| grep "Launching batch job 17"
slurmd: Launching batch job 17 for UID 0
[user@desktop ~]$
```


Run `cat ~/.nextflow.log` in the _slurmctld_ container

```
[root@slurmctld ~]# cat ~/.nextflow.log
Dec-05 09:59:02.123 [main] DEBUG nextflow.cli.Launcher - $> nextflow run blast-example -qs 12 -with-podman --chunkSize 3
Dec-05 09:59:02.193 [main] INFO  nextflow.cli.CmdRun - N E X T F L O W  ~  version 20.10.0
Dec-05 09:59:02.218 [main] DEBUG nextflow.scm.AssetManager - Listing projects in folder: /data/sshocker_shared/nextflowhome2/.nextflow/assets
Dec-05 09:59:02.229 [main] INFO  nextflow.cli.CmdRun - Pulling nextflow-io/blast-example ...
Dec-05 09:59:02.230 [main] DEBUG nextflow.scm.RepositoryProvider - Request [credentials -:-] -> https://api.github.com/repos/nextflow-io/blast-example/contents/nextflow.config
Dec-05 09:59:03.430 [main] DEBUG nextflow.scm.RepositoryProvider - Request [credentials -:-] -> https://api.github.com/repos/nextflow-io/blast-example/contents/main.nf
Dec-05 09:59:03.614 [main] DEBUG nextflow.scm.RepositoryProvider - Request [credentials -:-] -> https://api.github.com/repos/nextflow-io/blast-example
Dec-05 09:59:03.828 [main] DEBUG nextflow.scm.AssetManager - Pulling nextflow-io/blast-example -- Using remote clone url: https://github.com/nextflow-io/blast-example.git
Dec-05 09:59:04.832 [main] INFO  nextflow.cli.CmdRun -  downloaded from https://github.com/nextflow-io/blast-example.git
Dec-05 09:59:04.858 [main] INFO  nextflow.cli.CmdRun - Launching `nextflow-io/blast-example` [irreverent_bernard] - revision: 25922a0ae6 [master]
Dec-05 09:59:04.875 [main] DEBUG nextflow.config.ConfigBuilder - Found config home: /data/sshocker_shared/nextflowhome2/.nextflow/config
Dec-05 09:59:04.875 [main] DEBUG nextflow.config.ConfigBuilder - Found config base: /data/sshocker_shared/nextflowhome2/.nextflow/assets/nextflow-io/blast-example/nextflow.config
Dec-05 09:59:04.876 [main] DEBUG nextflow.config.ConfigBuilder - Parsing config file: /data/sshocker_shared/nextflowhome2/.nextflow/config
Dec-05 09:59:04.876 [main] DEBUG nextflow.config.ConfigBuilder - Parsing config file: /data/sshocker_shared/nextflowhome2/.nextflow/assets/nextflow-io/blast-example/nextflow.config
Dec-05 09:59:04.882 [main] DEBUG nextflow.config.ConfigBuilder - Applying config profile: `standard`
Dec-05 09:59:04.925 [main] DEBUG nextflow.config.ConfigBuilder - Applying config profile: `standard`
Dec-05 09:59:04.951 [main] DEBUG nextflow.config.ConfigBuilder - Enabling execution in Podman container as requested by cli option `-with-podman null`
Dec-05 09:59:04.989 [main] DEBUG nextflow.Session - Session uuid: 082c8487-b30a-4649-83c4-fdcc0e480bed
Dec-05 09:59:04.989 [main] DEBUG nextflow.Session - Run name: irreverent_bernard
Dec-05 09:59:04.990 [main] DEBUG nextflow.Session - Executor pool size: 4
Dec-05 09:59:05.015 [main] DEBUG nextflow.cli.CmdRun -
  Version: 20.10.0 build 5430
  Created: 01-11-2020 15:14 UTC
  System: Linux 5.4.0-56-generic
  Runtime: Groovy 3.0.5 on OpenJDK 64-Bit Server VM 11.0.9+11
  Encoding: UTF-8 (UTF-8)
  Process: 470@slurmctld [10.0.2.100]
  CPUs: 4 - Mem: 15.5 GB (1 GB) - Swap: 2 GB (2 GB)
Dec-05 09:59:05.035 [main] DEBUG nextflow.Session - Work-dir: /data/sshocker_shared/nextflowhome2/work [ext2/ext3]
Dec-05 09:59:05.035 [main] DEBUG nextflow.Session - Script base path does not exist or is not a directory: /data/sshocker_shared/nextflowhome2/.nextflow/assets/nextflow-io/blast-example/bin
Dec-05 09:59:05.072 [main] DEBUG nextflow.Session - Observer factory: TowerFactory
Dec-05 09:59:05.074 [main] DEBUG nextflow.Session - Observer factory: DefaultObserverFactory
Dec-05 09:59:05.235 [main] DEBUG nextflow.Session - Session start invoked
Dec-05 09:59:05.548 [main] DEBUG nextflow.script.ScriptRunner - > Launching execution
Dec-05 09:59:05.557 [main] DEBUG nextflow.Session - Workflow process names [dsl1]: extract, blast
Dec-05 09:59:05.672 [Actor Thread 1] DEBUG n.splitter.AbstractTextSplitter - Splitter `Fasta` collector path: nextflow.splitter.TextFileCollector$CachePath(/data/sshocker_shared/nextflowhome2/work/0b/223fbbdba24f70485623605bc375bc/sample.fa, null)
Dec-05 09:59:05.736 [main] DEBUG nextflow.executor.ExecutorFactory - << taskConfig executor: slurm
Dec-05 09:59:05.739 [main] DEBUG nextflow.executor.ExecutorFactory - >> processorType: 'slurm'
Dec-05 09:59:05.751 [main] DEBUG nextflow.executor.Executor - [warm up] executor > slurm
Dec-05 09:59:05.758 [main] DEBUG n.processor.TaskPollingMonitor - Creating task monitor for executor 'slurm' > capacity: 12; pollInterval: 5s; dumpInterval: 5m
Dec-05 09:59:05.766 [main] DEBUG n.executor.AbstractGridExecutor - Creating executor 'slurm' > queue-stat-interval: 1m
Dec-05 09:59:05.838 [main] DEBUG nextflow.executor.ExecutorFactory - << taskConfig executor: slurm
Dec-05 09:59:05.838 [main] DEBUG nextflow.executor.ExecutorFactory - >> processorType: 'slurm'
Dec-05 09:59:05.894 [main] DEBUG nextflow.script.ScriptRunner - > Await termination
Dec-05 09:59:05.894 [main] DEBUG nextflow.Session - Session await
Dec-05 09:59:06.026 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process blast (1) > jobId: 14; workDir: /data/sshocker_shared/nextflowhome2/work/d4/783af283d4976d53c5696aea0b997b
Dec-05 09:59:06.030 [Task submitter] INFO  nextflow.Session - [d4/783af2] Submitted process > blast (1)
Dec-05 09:59:06.046 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process blast (2) > jobId: 15; workDir: /data/sshocker_shared/nextflowhome2/work/b9/51bc58d8a55df65387afc6b217947b
Dec-05 09:59:06.046 [Task submitter] INFO  nextflow.Session - [b9/51bc58] Submitted process > blast (2)
Dec-05 09:59:10.778 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 14; id: 1; name: blast (1); status: COMPLETED; exit: 0; error: -; workDir: /data/sshocker_shared/nextflowhome2/work/d4/783af283d4976d53c5696aea0b997b started: 1607162350774; exited: 2020-12-05T09:59:07.549659Z; ]
Dec-05 09:59:10.794 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 15; id: 2; name: blast (2); status: COMPLETED; exit: 0; error: -; workDir: /data/sshocker_shared/nextflowhome2/work/b9/51bc58d8a55df65387afc6b217947b started: 1607162350791; exited: 2020-12-05T09:59:08.185649Z; ]
Dec-05 09:59:10.813 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process extract (1) > jobId: 16; workDir: /data/sshocker_shared/nextflowhome2/work/53/e70f7e6bc663e02f5f3f01a11f8dd3
Dec-05 09:59:10.813 [Task submitter] INFO  nextflow.Session - [53/e70f7e] Submitted process > extract (1)
Dec-05 09:59:10.827 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process extract (2) > jobId: 17; workDir: /data/sshocker_shared/nextflowhome2/work/fb/34a244fa05ee0523944ecf465fa5d5
Dec-05 09:59:10.828 [Task submitter] INFO  nextflow.Session - [fb/34a244] Submitted process > extract (2)
Dec-05 09:59:15.772 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 16; id: 3; name: extract (1); status: COMPLETED; exit: 0; error: -; workDir: /data/sshocker_shared/nextflowhome2/work/53/e70f7e6bc663e02f5f3f01a11f8dd3 started: 1607162355767; exited: 2020-12-05T09:59:11.617595Z; ]
Dec-05 09:59:15.776 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 17; id: 4; name: extract (2); status: COMPLETED; exit: 0; error: -; workDir: /data/sshocker_shared/nextflowhome2/work/fb/34a244fa05ee0523944ecf465fa5d5 started: 1607162355775; exited: 2020-12-05T09:59:11.913591Z; ]
Dec-05 09:59:15.778 [main] DEBUG nextflow.Session - Session await > all process finished
Dec-05 09:59:15.780 [main] DEBUG nextflow.Session - Session await > all barriers passed
Dec-05 09:59:15.859 [Actor Thread 3] DEBUG nextflow.sort.BigSort - Sort completed -- entries: 2; slices: 1; internal sort time: 0.013 s; external sort time: 0.001 s; total time: 0.014 s
Dec-05 09:59:15.877 [Actor Thread 3] DEBUG nextflow.file.FileCollector - Saved collect-files list to: /tmp/df7a0fb35e2e0e7bc9959f7d38812279.collect-file
Dec-05 09:59:15.888 [Actor Thread 3] DEBUG nextflow.file.FileCollector - Deleting file collector temp dir: /tmp/nxf-18216235904185588030
Dec-05 09:59:15.893 [main] DEBUG nextflow.trace.WorkflowStatsObserver - Workflow completed > WorkflowStats[succeededCount=4; failedCount=0; ignoredCount=0; cachedCount=0; pendingCount=0; submittedCount=0; runningCount=0; retriesCount=0; abortedCount=0; succeedDuration=11ms; failedDuration=0ms; cachedDuration=0ms;loadCpus=0; loadMemory=0; peakRunning=1; peakCpus=1; peakMemory=0; ]
Dec-05 09:59:15.932 [main] DEBUG nextflow.CacheDB - Closing CacheDB done
Dec-05 09:59:15.936 [main] DEBUG nextflow.util.SpuriousDeps - AWS S3 uploader shutdown
Dec-05 09:59:15.946 [main] DEBUG nextflow.script.ScriptRunner - > Execution complete -- Goodbye
[root@slurmctld ~]#
```

Note, the _~/.nextflow.log_ above is the same file as _~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/nextflowhome/.nextflow.log_ on the laptop.

```
me@laptop$ cat ~/.config/slurm-container-cluster/slurm_jobdir/sshocker_shared/nextflowhome/.nextflow.log | head -2
Dec-05 09:59:02.123 [main] DEBUG nextflow.cli.Launcher - $> nextflow run blast-example -qs 12 -with-podman --chunkSize 3
Dec-05 09:59:02.193 [main] INFO  nextflow.cli.CmdRun - N E X T F L O W  ~  version 20.10.0
```

