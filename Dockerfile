# GeoIP db from MaxMind
FROM debian:12-slim@sha256:d365f4920711a9074c4bcd178e8f457ee59250426441ab2a5f8106ed8fe948eb AS geo-ip
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
FROM python:3.12-slim-bookworm AS os-base
ARG ODOO_VERSION=18.0 \
    ODOO_SOURCE=odoo/odoo \
    ODOO_BUILD=0
ENV ODOO_VERSION="$ODOO_VERSION" \
    ODOO_SOURCE="$ODOO_SOURCE" \
    ODOO_USER=odoo \
    ODOO_GROUP=odoo \
    ODOO_UID=1000 \
    ODOO_GID=1000 \
    ODOO_HOME=/home/odoo
ENV SOURCES=$ODOO_HOME/src \
    CUSTOM=$ODOO_HOME/custom \
    RESOURCES=$ODOO_HOME/.resources \
    CONFIG_DIR=$ODOO_HOME/.config \
    DATA_DIR=$ODOO_HOME/data
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
    ADMIN_PASSWORD=admin \
    # https://odoo-community.org/groups/contributors-15/contributors-186006?mode=thread&date_begin=&date_end=
    OPENBLAS_NUM_THREADS=1
ENV PATH=$ODOO_HOME/venv/bin:$PATH:$ODOO_HOME/.local/bin
EXPOSE 8069 8072

# TODO: See COPY --parents (next Dockerfile release)
COPY --chown=$ODOO_UID:$ODOO_GID ./$ODOO_VERSION/.bash_aliases /tmp/.bash_aliases
COPY --chown=$ODOO_UID:$ODOO_GID ./$ODOO_VERSION/bin/ /tmp/bin
COPY --chown=$ODOO_UID:$ODOO_GID ./$ODOO_VERSION/resources/ /tmp/resources
# COPY UNRAR libs
COPY --from=unrar --chown=root:root --chmod=755 /usr/lib/libunrar.* /usr/lib/

RUN --mount=type=bind,src=./$ODOO_VERSION/requirements/common/common.packages,dst=/common.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/common/requirements.txt,dst=/common.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/base/build.packages,dst=/odoo.build.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/base/requirements.txt,dst=/odoo.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/requirements.txt,dst=/odoo.adhoc.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/build.packages,dst=/odoo.adhoc.build.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/extra.packages,dst=/odoo.adhoc.extra.packages \
    #### Enable Odoo user and filestore
    groupadd --gid $ODOO_GID $ODOO_GROUP \
    && useradd -u $ODOO_UID -md $ODOO_HOME $ODOO_USER -g $ODOO_GROUP -s /bin/false \
    && chsh -s /bin/bash $ODOO_USER \
    && su $ODOO_USER -c "\
        mkdir -p $RESOURCES \
        && mkdir -p $SOURCES/repositories \
        && mkdir -p $CUSTOM/repositories \
        && mkdir -p $DATA_DIR \
        && mkdir -p $CONFIG_DIR \
        && mkdir -p $ODOO_HOME/.local/bin/ \
        && mv /tmp/.bash_aliases $ODOO_HOME/.bash_aliases \
        && mv /tmp/bin/* $ODOO_HOME/.local/bin/ \
        && mv /tmp/resources/* $RESOURCES/ \
        && ln $ODOO_HOME/.local/bin/direxec $RESOURCES/entrypoint \
        && ln $ODOO_HOME/.local/bin/direxec $RESOURCES/build \
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
    && rm -Rf wkhtmltox.deb libjpeg-turbo8.deb \
    #### Common
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && grep -v '^#' /common.packages | xargs apt-get install -yqq --no-install-recommends \
    && chsh -s /bin/bash $ODOO_USER \
    # Create venv for odoo
    && su $ODOO_USER -c "python -m venv $ODOO_HOME/venv" \
    # Upgrade pip (user level)
    && su $ODOO_USER -c "pip install --upgrade pip" \
    # Sice this point we are using the venv (pip and python command refer to the venv)
    && su $ODOO_USER -c "pip install --no-cache-dir --prefer-binary -r /common.requirements.txt \
        && python -m compileall -q $ODOO_HOME/venv/lib/python*/" \
    && chsh -s /bin/false $ODOO_USER \
    #### Install Odoo hard & soft dependencies
    && grep -v '^#' /odoo.build.packages | xargs apt-get install -yqq --no-install-recommends \
    && chsh -s /bin/bash $ODOO_USER \
    && su $ODOO_USER -c "pip install --no-cache-dir --prefer-binary -r /odoo.requirements.txt \
        && python -m compileall -q $ODOO_HOME/venv/lib/python*/" \
    && chsh -s /bin/false $ODOO_USER \
    && grep -v '^#' /odoo.build.packages | xargs apt-get purge -yqq \
    #### Odoo by Adhoc requirements
    && grep -v '^#' /odoo.adhoc.extra.packages | xargs apt-get install -yqq --no-install-recommends \
    && grep -v '^#' /odoo.adhoc.build.packages | xargs apt-get install -yqq --no-install-recommends \
    # Enabling shell for odoo user
    && chsh -s /bin/bash $ODOO_USER \
    && su $ODOO_USER -c "pip install --no-cache-dir --prefer-binary -r /odoo.adhoc.requirements.txt \
        && python -m compileall -q $ODOO_HOME/venv/lib/python*/" \
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
    && grep -v '^#' /odoo.adhoc.build.packages | xargs apt-get purge -yqq \
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
ARG ODOO_BY_ADHOC_BUILD \
    ODOO_MINOR_VERSION
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
    && echo "$ODOO_VERSION.$ODOO_MINOR_VERSION" > ODOO_BY_ADHOC_VERSION
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
    # Aggregate new repositories of this image # TODO: NO PERMITIR INSTALACIONES DE LOS REPOSITORIOS
    && autoaggregate --config "$RESOURCES/saas-odoo_project_repos.yml" --output "$SOURCES/repositories" \
    && autoaggregate --config "$RESOURCES/saas-odoo_project_version_repos.yml" --output "$SOURCES/repositories" \
    && find $SOURCES -name "*.git" -type d -execdir sh -c "pwd && echo , && git log  -n 1  --remotes=origin --pretty=format:\"%H\" && echo \;; " \; | xargs -n3 > $ODOO_HOME/repo_heads.txt \
    && curl -X POST $BASE_URL/report_sha$URL_SUFIX\&minor_version=`date -u +%Y.%m.%d` -H "Content-Type: application/json" -H "Accept: application/json" -d "@$ODOO_HOME/repo_heads.txt" \
    && unset BASE_URL URL_SUFIX

## PROD IMAGE

FROM aggregate-source AS aggregate-source-without-git
RUN find $SOURCES \( -path $SOURCES/openupgradelib -o -path $SOURCES/upgrade-util \) -prune -o -type d -name ".git" -exec rm -rf {} +

# TODO: See: COPY --exclude (next Dockerfile release)
FROM os-base-updated AS prod
COPY --from=aggregate-source-without-git --chown=$ODOO_USER:$ODOO_USER $SOURCES $SOURCES
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml $RESOURCES
RUN --mount=type=secret,id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --mount=type=secret,id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --mount=type=secret,id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    autoaggregate_pip --config "$RESOURCES/saas-odoo_project_repos.yml" --output "$SOURCES/repositories" \
    && autoaggregate_pip --config "$RESOURCES/saas-odoo_project_version_repos.yml" --output "$SOURCES/repositories" \
    && rm $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml \
    # ini - upgrade-util install issue
    && rm -rf $SOURCES/upgrade-util/src/mail $SOURCES/upgrade-util/src/base/ \
    && mv -f $SOURCES/upgrade-util/src/* $SOURCES/odoo/odoo/upgrade \
    && rm -rf $ODOO_HOME/venv/lib/python*/site-packages/odoo \
    # end - upgrade-util install issue
    && pip install --no-cache-dir -e $SOURCES/odoo

## DEV IMAGE

FROM os-base-updated AS dev
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $SOURCES $SOURCES
COPY --from=aggregate-source --chown=$ODOO_USER:$ODOO_USER $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml $RESOURCES
USER root
RUN --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/dev/dev.packages,dst=/tools.dev.dev.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/dev/requirements.txt,dst=/tools.dev.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/dev/bashrc.sh,dst=/tools.dev.bashrc.sh \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/test/test.packages,dst=/tools.test.test.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/test/requirements.txt,dst=/tools.test.requirements.txt \
    --mount=type=secret,id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --mount=type=secret,id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --mount=type=secret,id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    apt-get -qq update \
    && chsh -s /bin/bash $ODOO_USER \
    # Dev Tools ( Used by developers )
    && grep -v '^#' /tools.dev.dev.packages | xargs apt-get install -yqq --no-install-recommends \
    && su $ODOO_USER -c "pip install --no-cache-dir --prefer-binary -r /tools.dev.requirements.txt" \
    && su $ODOO_USER -c "python -m compileall -q $ODOO_HOME/venv/lib/python*/" \
    && cat /tools.dev.bashrc.sh >> $ODOO_HOME/.bashrc \
    # Test Tools ( Used by runbot )
    && grep -v '^#' /tools.test.test.packages | xargs apt-get install -yqq --no-install-recommends \
    && su $ODOO_USER -c "pip install --no-cache-dir --prefer-binary -r /tools.test.requirements.txt" \
    && su $ODOO_USER -c "python -m compileall -q $ODOO_HOME/venv/lib/python*/" \
    && su $ODOO_USER -c "autoaggregate_pip --config \"$RESOURCES/saas-odoo_project_repos.yml\" --output \"$SOURCES/repositories\"" \
    && su $ODOO_USER -c "autoaggregate_pip --config \"$RESOURCES/saas-odoo_project_version_repos.yml\" --output \"$SOURCES/repositories\"" \
    && rm $RESOURCES/saas-odoo_project_repos.yml $RESOURCES/saas-odoo_project_version_repos.yml \
    # ini - upgrade-util install issue
    && su $ODOO_USER -c "rm -rf $SOURCES/upgrade-util/src/mail $SOURCES/upgrade-util/src/base/" \
    && su $ODOO_USER -c "mv -f $SOURCES/upgrade-util/src/* $SOURCES/odoo/odoo/upgrade" \
    && su $ODOO_USER -c "rm -rf $ODOO_HOME/venv/lib/python*/site-packages/odoo" \
    # Skip these files in git tracking
    && su $ODOO_USER -c "cd $SOURCES/odoo/odoo/upgrade; git update-index --assume-unchanged $(git ls-files | tr '\n' ' '); cd -" \
    # end - upgrade-util install issue
    && su $ODOO_USER -c "pip install --no-cache-dir -e $SOURCES/odoo" \
    && echo "$ODOO_USER  ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$ODOO_USER
USER $ODOO_USER
