ARG BASE_IMAGE_REPO
ARG BASE_IMAGE_TAG

FROM $BASE_IMAGE_REPO:$BASE_IMAGE_TAG

ARG GITHUB_USER
ARG GITHUB_TOKEN
ARG GITLAB_USER
ARG GITLAB_TOKEN
ARG DOCKER_IMAGE
ARG DOCKER_TAG_SUFFIX
ARG SAAS_PROVIDER_URL
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
        ca-certificates \
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
    && sudo -H -u odoo pip install --user --no-cache-dir pycurl redis==2.10.5 \
    # purge
    && apt-get purge -yqq build-essential '*-dev' make || true \
    && apt-get -yqq autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER odoo

# Add new entrypoints and configs
COPY entrypoint.d/* $RESOURCES/entrypoint.d/
COPY conf.d/* $RESOURCES/conf.d/

# Add resources.
COPY resources/$ODOO_VERSION/* $RESOURCES/

ENV BASE_URL="${SAAS_PROVIDER_URL}/odoo_project"
ENV URL_SUFIX="?docker_image=${DOCKER_IMAGE}&major_version=${ODOO_VERSION}&suffix=${DOCKER_TAG_SUFFIX}&token=${SAAS_PROVIDER_TOKEN}"

# get repos from odoo-version-group and odoo-version
RUN wget -O $RESOURCES/saas-odoo_project_repos.yml $BASE_URL/repos.yml$URL_SUFIX
RUN wget -O $RESOURCES/saas-odoo_project_version_repos.yml $BASE_URL/repos.yml$URL_SUFIX\&minor_version=`date -u +%Y.%m.%d`
RUN wget -O $RESOURCES/saas-build $BASE_URL/build$URL_SUFIX && chmod +x $RESOURCES/saas-build
RUN wget -O $RESOURCES/entrypoint.d/999-saas-entrypoint $BASE_URL/entrypoint$URL_SUFIX && chmod +x $RESOURCES/entrypoint.d/999-saas-entrypoint
RUN wget -O $RESOURCES/conf.d/999-saas-custom.conf $BASE_URL/custom.conf$URL_SUFIX

# Run custom build hook
USER root
RUN $RESOURCES/saas-build
USER odoo

# Aggregate new repositories of this image
RUN autoaggregate --config "$RESOURCES/saas-odoo_project_repos.yml" --install --output $SOURCES/repositories
RUN autoaggregate --config "$RESOURCES/saas-odoo_project_version_repos.yml" --install --output $SOURCES/repositories
