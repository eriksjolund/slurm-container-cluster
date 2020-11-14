FROM docker.io/giovtorres/slurm-docker-cluster:latest
RUN curl -o /usr/local/bin/norouter --fail -L https://github.com/norouter/norouter/releases/latest/download/norouter-$(uname -s)-$(uname -m) && \
    chmod 755 /usr/local/bin/norouter && \
    chown munge:munge /var/run/munge && \
    sed -i 's/socket=\/var\/lib\/mysql\/mysql.sock/socket=\/var\/run\/mysqld\/mysqld.sock/g' /etc/my.cnf
