ARG MYSQL_VERSION=5.7
FROM docker.io/library/mysql:${MYSQL_VERSION}
ARG NOROUTER_VERSION=v0.6.1
RUN apt-get update \
    && apt-get install -y curl \
    && curl -fsSL https://github.com/norouter/norouter/releases/download/${NOROUTER_VERSION}/norouter-$(uname -s)-$(uname -m).tgz | tar xzvC /usr/local/bin \
    && rm -rf /var/lib/apt/lists/*
