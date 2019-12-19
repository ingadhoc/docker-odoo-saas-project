ARG BASE_IMAGE_REPO
ARG BASE_IMAGE_TAG

FROM $BASE_IMAGE_REPO:$BASE_IMAGE_TAG

ARG GITHUB_USER
ARG GITHUB_TOKEN
ARG GITLAB_USER
ARG GITLAB_TOKEN
ARG SAAS_PROVIDER_URL
ARG SAAS_PROVIDER_PROJECT_ID
ARG SAAS_PROVIDER_TOKEN
ENV GITHUB_USER="$GITHUB_USER"
ENV GITHUB_TOKEN="$GITHUB_TOKEN"
ENV GITLAB_USER="$GITLAB_USER"
ENV GITLAB_TOKEN="$GITLAB_TOKEN"

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

ENV BASE_URL=$SAAS_PROVIDER_URL/odoo_project/$SAAS_PROVIDER_PROJECT_ID

# get repos from odoo-version-group and odoo-version
RUN wget -O $RESOURCES/odoo_project_repos.yml $BASE_URL/repos.yml?token=$SAAS_PROVIDER_TOKEN
RUN wget -O $RESOURCES/odoo_project_version_repos.yml $BASE_URL/`date -u +%Y.%m.%d`/repos.yml?token=$SAAS_PROVIDER_TOKEN
RUN wget -O $RESOURCES/custom-build $BASE_URL/build?token=$SAAS_PROVIDER_TOKEN && chmod +x $RESOURCES/custom-build
RUN wget -O $RESOURCES/entrypoint.d/999-custom-entrypoint $BASE_URL/entrypoint?token=$SAAS_PROVIDER_TOKEN && chmod +x $RESOURCES/entrypoint.d/999-custom-entrypoint
RUN wget -O $RESOURCES/conf.d/custom.conf $BASE_URL/custom.conf?token=$SAAS_PROVIDER_TOKEN

# Run custom build hook, if available
USER root
RUN $RESOURCES/build
RUN $RESOURCES/custom-build
USER odoo

# Aggregate new repositories of this image
RUN autoaggregate --config "$RESOURCES/odoo_project_repos.yml" --install --output $SOURCES/repositories
RUN autoaggregate --config "$RESOURCES/odoo_project_version_repos.yml" --install --output $SOURCES/repositories
