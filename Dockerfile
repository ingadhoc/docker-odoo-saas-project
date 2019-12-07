ARG IMAGE=adhoc/odoo
ARG BASETAG=odoo-e
ARG ODOO_VERSION=12.0

FROM $IMAGE:$ODOO_VERSION.$BASETAG

ARG GITHUB_USER
ARG GITHUB_TOKEN
ENV GITHUB_USER="$GITHUB_USER"
ENV GITHUB_TOKEN="$GITHUB_TOKEN"

# Default env values used by config generator
ENV FILESTORE_OPERATIONS_THREADS=3 \
    FILESTORE_COPY_HARD_LINK=True \
    ENABLE_REDIS=False \
    REDIS_HOST=localhost \
    REDIS_PORT=6379 \
    REDIS_DBINDEX=1 \
    REDIS_PASS=False

# Add other dependencies
USER root
RUN apt-get update \
    && apt-get install -y \
        build-essential \
        libcups2-dev \
        libcurl4-openssl-dev \
        parallel \
        python3-dev \
        libevent-dev \
        libjpeg-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        swig \
    # pip dependencies that require build deps
    && pip3 install pycurl redis==2.10.5 \
    # purge
    && apt-get purge -yqq build-essential '*-dev' make \
    && apt-get -yqq autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER odoo

# Add patched server.py. Hacked to avoid creating a new database if it doesn't exist, when sending db_name
ADD server.py /home/odoo/.local/lib/python3.5/site-packages/odoo/cli/

# Add new entrypoints and configs
COPY entrypoint.d/* $RESOURCES/entrypoint.d/
COPY conf.d/* $RESOURCES/conf.d/

# Aggregate new repositories of this image
COPY repos.yml $RESOURCES/
RUN autoaggregate --config "$RESOURCES/repos.yml" --install --output $SOURCES/repositories
