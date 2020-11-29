FROM localhost/slurm-container-cluster

 RUN dnf -y install \
       java-11-openjdk \
     && dnf clean all \
     && rm -rf /var/cache/yum

RUN cd / && curl -s https://get.nextflow.io | bash && mv /nextflow /usr/local/bin
