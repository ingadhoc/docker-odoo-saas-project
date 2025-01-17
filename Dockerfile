# GeoIP db from MaxMind
FROM debian:12-slim AS geo-ip
ARG MAXMIND_UPDATE=default
RUN --mount=type=secret,id=MAXMIND_LICENSE_KEY,env=MAXMIND_LICENSE_KEY \
    --mount=type=secret,id=MAXMIND_LICENSE_USR,env=MAXMIND_LICENSE_USR \
    mkdir -p /GeoIP \
    && cd /GeoIP \
    && apt-get -qq update \
    && apt-get install -yqq --no-install-recommends curl ca-certificates \
    && curl -L -u ${MAXMIND_LICENSE_USR}:${MAXMIND_LICENSE_KEY} "https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz" -o /GeoIP/GeoLite2-City.tar.gz \
    && tar -xzf /GeoIP/GeoLite2-City.tar.gz -C /GeoIP \
    && find /GeoIP/GeoLite2-City_* | grep "GeoLite2-City.mmdb" | xargs -I{} mv {} /GeoIP \
    && rm /GeoIP/GeoLite2-City.tar.gz \
    && apt-get purge -yqq curl ca-certificates \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# unrar library used by (saas_provider_adhoc and agip list)
# This image prepare this 2 files, so you can copy directly to your image
# COPY --from=unrar --chown=root:root --chmod=755 /usr/lib/libunrar.* /usr/lib/
FROM debian:12-slim@sha256:d365f4920711a9074c4bcd178e8f457ee59250426441ab2a5f8106ed8fe948eb AS unrar
RUN apt-get -qq update \
    && apt-get install -yqq --no-install-recommends wget build-essential ca-certificates \
    && wget https://www.rarlab.com/rar/unrarsrc-5.6.8.tar.gz \
    && tar -xf unrarsrc-5.6.8.tar.gz \
    && cd unrar \
    && make lib \
    && make install-lib \
    && rm -rf /unrarsrc-5.6.8.tar.gz \
    && rm -rf /unrar \
    && apt-get purge -yqq wget build-essential ca-certificates \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

##### END AUX IMAGES

# ODOO COMMON IMAGE
FROM python:3.10-slim-bookworm AS os-base
ARG ODOO_VERSION=18.0 \
    ODOO_SOURCE=odoo/odoo \
    ODOO_BUILD=0
ENV ODOO_VERSION="$ODOO_VERSION" \
    ODOO_SOURCE="$ODOO_SOURCE" \
    ODOO_USER=odoo \
    ODOO_GROUP=odoo \
    ODOO_UID=1000 \
    ODOO_GID=1000
ENV SOURCES=/home/odoo/src \
    CUSTOM=/home/odoo/custom \
    RESOURCES=/home/odoo/.resources \
    CONFIG_DIR=/home/odoo/.config \
    DATA_DIR=/home/odoo/data
ENV OPENERP_SERVER=$CONFIG_DIR/odoo.conf
ENV ODOO_RC=$OPENERP_SERVER

# Default values of env variables used by scripts
ENV ODOO_SERVER=odoo \
    UNACCENT=True \
    PROXY_MODE=True \
    WITHOUT_DEMO=True \
    WAIT_PG=true \
    PGUSER=odoo \
    PGPASSWORD=odoo \
    PGHOST=db \
    PGPORT=5432 \
    ADMIN_PASSWORD=admin
ENV PATH=$PATH:/home/odoo/.local/bin

EXPOSE 8069 8072

# TODO: See COPY --parents (next Dockerfile release)
COPY --chown=$ODOO_UID:$ODOO_GID .bash_aliases /tmp/.bash_aliases
COPY --chown=$ODOO_UID:$ODOO_GID ./bin/ /tmp/bin
COPY --chown=$ODOO_UID:$ODOO_GID ./resources/ /tmp/resources
# COPY UNRAR libs
COPY --from=unrar --chown=root:root --chmod=755 /usr/lib/libunrar.* /usr/lib/
# Enable Odoo user and filestore
RUN groupadd --gid $ODOO_GID $ODOO_GROUP \
    && useradd -u $ODOO_UID -md /home/odoo $ODOO_USER -g $ODOO_GROUP -s /bin/false \
    && chsh -s /bin/bash $ODOO_USER \
    && su - $ODOO_USER -c "\
        mkdir -p $RESOURCES \
        && mkdir -p $SOURCES/repositories \
        && mkdir -p $CUSTOM/repositories \
        && mkdir -p $DATA_DIR \
        && mkdir -p $CONFIG_DIR \
        && mkdir -p /home/odoo/.local/bin/ \
        && mv /tmp/.bash_aliases /home/odoo/.bash_aliases \
        && mv /tmp/bin/* /home/odoo/.local/bin/ \
        && mv /tmp/resources/* $RESOURCES/ \
        && ln /home/odoo/.local/bin/direxec $RESOURCES/entrypoint \
        && ln /home/odoo/.local/bin/direxec $RESOURCES/build \
    " \
    && rm -rf /tmp/* \
    && chsh -s /bin/false $ODOO_USER \
    # Used defined build options
    && $RESOURCES/build \
    # WKHTMLTOPDF
    && apt-get -qq update \
    # TODO: WKHTMLTOPDF_VERSION
    && apt-get install -yqq --no-install-recommends curl \
    && curl -sLo libjpeg-turbo8.deb http://mirrors.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.1.2-0ubuntu1_amd64.deb \
    && curl -sLo wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb \
    && apt-get install -yqq --no-install-recommends \
        ./libjpeg-turbo8.deb \
        ./wkhtmltox.deb \
    && apt-get purge -yqq curl \
    && apt-get autopurge -yqq \
    && rm -Rf wkhtmltox.deb libjpeg-turbo8.deb /var/lib/apt/lists/* /tmp/*

# Common
RUN --mount=type=bind,src=requirements/common/common.packages,dst=/common.packages \
    --mount=type=bind,src=requirements/common/requirements.txt,dst=/home/odoo/common.requirements.txt \
    apt-get -qq update \
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && grep -v '^#' /common.packages | xargs apt-get install -yqq --no-install-recommends \
    && chsh -s /bin/bash $ODOO_USER \
    && su - $ODOO_USER -c "pip install --user --upgrade pip" \
    && su - $ODOO_USER -c "pip install --user --no-cache-dir --prefer-binary -r /home/odoo/common.requirements.txt" \
    && su - $ODOO_USER -c "python3 -m compileall -q  /home/odoo/.local/lib/python*/" \
    && chsh -s /bin/false $ODOO_USER \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Install Odoo hard & soft dependencies
ADD --chown=$ODOO_USER:$ODOO_USER https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt /odoo.requirements.txt
RUN --mount=type=bind,src=requirements/odoo/base/build.packages,dst=/odoo.build.packages \
    apt-get -qq update \
    && grep -v '^#' /odoo.build.packages | xargs apt-get install -yqq --no-install-recommends \
    # Issue: https://github.com/odoo/odoo/issues/187021
    && sed -i "s/gevent==21\.8\.0 ; sys_platform != 'win32' and python_version == '3\.10'  # (Jammy)/gevent==21.12.0 ; sys_platform != 'win32' and python_version == '3.10'  # (Jammy)/" odoo.requirements.txt \
    && sed -i "s/geoip2==2\.9\.0/geoip2==4.6.0/" odoo.requirements.txt \
    # End Issue
    && chsh -s /bin/bash $ODOO_USER \
    && su - $ODOO_USER -c "pip install --user --no-cache-dir --prefer-binary -r /odoo.requirements.txt" \
    && su - $ODOO_USER -c "python3 -m compileall -q  /home/odoo/.local/lib/python*/" \
    && chsh -s /bin/false $ODOO_USER \
    && rm /odoo.requirements.txt \
    && grep -v '^#' /odoo.build.packages | xargs apt-get purge -yqq \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Odoo by Adhoc requirements
RUN --mount=type=bind,src=requirements/odoo/adhoc/requirements.txt,dst=/home/odoo/odoo.adhoc.requirements.txt \
    --mount=type=bind,src=requirements/odoo/adhoc/build.packages,dst=/home/odoo/odoo.adhoc.build.packages \
    --mount=type=bind,src=requirements/odoo/adhoc/extra.packages,dst=/home/odoo/odoo.adhoc.extra.packages \
    apt-get -qq update \
    && grep -v '^#' /home/odoo/odoo.adhoc.extra.packages | xargs apt-get install -yqq --no-install-recommends \
    && grep -v '^#' /home/odoo/odoo.adhoc.build.packages | xargs apt-get install -yqq --no-install-recommends \
    # Enabling shell for odoo user
    && chsh -s /bin/bash $ODOO_USER \
    && su - $ODOO_USER -c "pip install --user --no-cache-dir --prefer-binary -r /home/odoo/odoo.adhoc.requirements.txt" \
    && su - $ODOO_USER -c "python3 -m compileall -q  /home/odoo/.local/lib/python*/" \
    # Disabling shell for odoo user
    && chsh -s /bin/false $ODOO_USER \
    # PG Client
    && apt-get install -yqq --no-install-recommends curl gnupg \
    && install -d /usr/share/postgresql-common/pgdg \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get -qq update \
    && apt-get install -yqq --no-install-recommends postgresql-client-15 \
    # Clean up
    && grep -v '^#' /home/odoo/odoo.adhoc.build.packages | xargs apt-get purge -yqq \
    && apt-get -yqq autoremove \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# required by saas_k8s (Helm)
COPY --from=alpine/helm --chmod=755 --chown=root:root /usr/bin/helm /usr/local/bin/helm

# GEOIP
COPY --from=geo-ip --chown=$ODOO_USER:$ODOO_USER /GeoIP $RESOURCES/GeoIP

# Entrypoint
WORKDIR "/home/odoo"
ENTRYPOINT ["/home/odoo/.resources/entrypoint.sh"]
CMD ["odoo"]
USER odoo

## ---------------------------------------------------------------- SO

FROM os-base AS os-base-updated
ARG ODOO_BY_ADHOC_BUILD=0
USER root
RUN export NEEDRESTART_MODE=a \
    && export DEBIAN_FRONTEND=noninteractive \
    ## Questions that you really, really need to see (or else). ##
    && export DEBIAN_PRIORITY=critical \
    && apt-get -qqy clean \
    && apt-get -qqy update \
    && apt-get -qqy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade \
    && apt-get -qqy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" dist-upgrade \
    && apt-get -qqy autoremove \
    && apt-get -qqy clean \
    && rm -Rf /var/lib/apt/lists/* /tmp/* \
    && echo "$ODOO_BY_ADHOC_BUILD" > ODOO_BY_ADHOC_BUILD
USER $ODOO_USER

FROM os-base-updated AS aggregate-source
ARG DOCKER_IMAGE="adhoc/odoo-adhoc" \
    ODOO_MINOR_VERSION=""
RUN --mount=type=secret,id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --mount=type=secret,id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --mount=type=secret,id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    git config --global init.defaultBranch main \
    && git config --global pull.rebase true \
    && git config --global user.name "John Doe" \
    && git config --global user.email johndoe@example.com \
    && BASE_URL="${SAAS_PROVIDER_URL}/odoo_project" \
    && URL_SUFIX="?docker_image=${DOCKER_IMAGE}&major_version=${ODOO_VERSION}&token=${SAAS_PROVIDER_TOKEN}" \
    # Get remote config from odoo-provider (odoo_project)
    && curl -L -sS -o $RESOURCES/saas-odoo_project_repos.yml "$BASE_URL/repos.yml$URL_SUFIX" \
    && curl -L -sS -o $RESOURCES/saas-odoo_project_version_repos.yml "$BASE_URL/repos.yml$URL_SUFIX&minor_version=${ODOO_MINOR_VERSION}" \
    && curl -L -sS -o $RESOURCES/saas-build "$BASE_URL/build$URL_SUFIX" && chmod +x $RESOURCES/saas-build \
    && curl -L -sS -o $RESOURCES/entrypoint.d/999-saas-entrypoint "$BASE_URL/entrypoint$URL_SUFIX" && chmod +x $RESOURCES/entrypoint.d/999-saas-entrypoint \
    && curl -L -sS -o $RESOURCES/conf.d/999-saas-custom.conf "$BASE_URL/custom.conf$URL_SUFIX" \
    # Aggregate new repositories of this image
    && autoaggregate --config "$RESOURCES/saas-odoo_project_repos.yml" --output "$SOURCES/repositories" \
    && autoaggregate --config "$RESOURCES/saas-odoo_project_version_repos.yml" --output "$SOURCES/repositories" \
    && find $SOURCES -name "*.git" -type d -execdir sh -c "pwd && echo , && git log  -n 1  --remotes=origin --pretty=format:\"%H\" && echo \;; " \; | xargs -n3 > /tmp/repo_heads.txt ; curl -X POST $BASE_URL/report_sha$URL_SUFIX\&minor_version=`date -u +%Y.%m.%d` -H "Content-Type: application/json" -H "Accept: application/json" -d "@/tmp/repo_heads.txt" \
    && unset BASE_URL URL_SUFIX

FROM aggregate-source AS aggregate-source-without-git
RUN find $SOURCES \( -path $SOURCES/openupgradelib -o -path $SOURCES/upgrade-util \) -prune -o -type d -name ".git" -exec rm -rf {} +

# TODO: See: COPY --exclude (next Dockerfile release)
FROM os-base-updated AS prod
COPY --from=aggregate-source-without-git --chown=$ODOO_USER:$ODOO_USER $SOURCES $SOURCES
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml $RESOURCES

RUN --mount=type=secret,id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --mount=type=secret,id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --mount=type=secret,id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    pip install --user --no-cache-dir -e $SOURCES/odoo \
    && autoaggregate_pip --config "$RESOURCES/saas-odoo_project_repos.yml" --output "$SOURCES/repositories" \
    && autoaggregate_pip --config "$RESOURCES/saas-odoo_project_version_repos.yml" --output "$SOURCES/repositories" \
    && rm $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml

FROM os-base-updated AS dev
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $SOURCES $SOURCES
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml $RESOURCES
USER root

RUN --mount=type=bind,src=requirements/tools/dev/dev.packages,dst=/home/odoo/tools.dev.dev.packages \
    --mount=type=bind,src=requirements/tools/test/test.packages,dst=/home/odoo/tools.test.test.packages \
    --mount=type=bind,src=requirements/tools/test/requirements.txt,dst=/home/odoo/tools.test.requirements.txt \
    --mount=type=secret,id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --mount=type=secret,id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --mount=type=secret,id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    apt-get -qq update \
    # Dev Tools ( Used by developers )
    && grep -v '^#' /home/odoo/tools.dev.dev.packages | xargs apt-get install -yqq --no-install-recommends \
    # Test Tools ( Used by runbot )
    && grep -v '^#' /home/odoo/tools.test.test.packages | xargs apt-get install -yqq --no-install-recommends \
    && chsh -s /bin/bash $ODOO_USER \
    && su - $ODOO_USER -c "pip install --user --no-cache-dir --prefer-binary -r /home/odoo/tools.test.requirements.txt" \
    && su - $ODOO_USER -c "python3 -m compileall -q  /home/odoo/.local/lib/python*/" \
    && su - $ODOO_USER -c "pip install --user --no-cache-dir -e $SOURCES/odoo" \
    && su - $ODOO_USER -c "autoaggregate_pip --config \"$RESOURCES/saas-odoo_project_repos.yml\" --output \"$SOURCES/repositories\"" \
    && su - $ODOO_USER -c "autoaggregate_pip --config \"$RESOURCES/saas-odoo_project_version_repos.yml\" --output \"$SOURCES/repositories\"" \
    && rm $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml \
    && chsh -s /bin/false $ODOO_USER
USER $ODOO_USER
