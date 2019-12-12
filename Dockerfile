ARG BASE_IMAGE_REPO=adhoc/odoo-oca
ARG BASE_IMAGE_TAG=12.0

FROM $BASE_IMAGE_REPO:$BASE_IMAGE_TAG AS adhoc

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

# Add new entrypoints and configs
COPY entrypoint.d/* $RESOURCES/entrypoint.d/
COPY conf.d/* $RESOURCES/conf.d/
COPY resources/$ODOO_VERSION/* $RESOURCES/

# Run custom build hook, if available
RUN $RESOURCES/build

# Aggregate new repositories of this image
RUN autoaggregate --config "$RESOURCES/repos.yml" --install --output $SOURCES/repositories

# get repos from odoo-version-group and odoo-version
RUN wget -O $RESOURCES/odoo_version_group_repos.yml wget https://www.adhoc.com.ar/odoo_version/$ODOO_VERSION_ID/repos.yml?token=$REPOS_YML_TOKEN
RUN wget -O $RESOURCES/odoo_version_repos.yml wget https://www.adhoc.com.ar/odoo_version/$ODOO_VERSION_ID/`date -u +%Y.%m.%d`/repos.yml?token=$REPOS_YML_TOKEN
RUN autoaggregate --config "$RESOURCES/odoo_version_group_repos.yml" --install --output $SOURCES/repositories
RUN autoaggregate --config "$RESOURCES/odoo_version_repos.yml" --install --output $SOURCES/repositories
