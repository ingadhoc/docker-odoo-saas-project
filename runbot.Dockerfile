ARG PYTHON_BASE_IMAGE=3.12-slim-bookworm

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

FROM python:${PYTHON_BASE_IMAGE} AS runbot
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
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/base/requirements.txt,dst=/base.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/tools/odoo_dep_fixer.sh,dst=/odoo_dep_fixer.sh \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/requirements.txt,dst=/odoo.adhoc.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/build.packages,dst=/odoo.adhoc.build.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/odoo/adhoc/extra.packages,dst=/odoo.adhoc.extra.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/dev/dev.packages,dst=/tools.dev.dev.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/dev/requirements.txt,dst=/tools.dev.requirements.txt \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/test/test.packages,dst=/tools.test.test.packages \
    --mount=type=bind,src=./$ODOO_VERSION/requirements/tools/test/requirements.txt,dst=/tools.test.requirements.txt \
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
    && apt-get -qq update \
    # User defined build options
    && $RESOURCES/build \
    #### Common
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && grep -v '^#' /common.packages | xargs apt-get install -yqq --no-install-recommends \
    && pip install --upgrade pip \
    && pip install --no-cache-dir --prefer-binary -r /common.requirements.txt \
    #### Install Odoo hard & soft dependencies
    && grep -v '^#' /odoo.build.packages | xargs apt-get install -yqq --no-install-recommends \
    && cp /base.requirements.txt /odoo.requirements.txt \
    && /odoo_dep_fixer.sh \
    && pip install --no-cache-dir --prefer-binary -r /odoo.requirements.txt \
    && rm /odoo.requirements.txt \
    && grep -v '^#' /odoo.build.packages | xargs apt-get purge -yqq \
    #### Odoo by Adhoc requirements
    && grep -v '^#' /odoo.adhoc.extra.packages | xargs apt-get install -yqq --no-install-recommends \
    && grep -v '^#' /odoo.adhoc.build.packages | xargs apt-get install -yqq --no-install-recommends \
    && pip install --no-cache-dir --prefer-binary -r /odoo.adhoc.requirements.txt \
    #### Dev requirements
    && grep -v '^#' /tools.dev.dev.packages | xargs apt-get install -yqq --no-install-recommends \
    && pip install --no-cache-dir --prefer-binary -r /tools.dev.requirements.txt \
    #### Test requirements
    && grep -v '^#' /tools.test.test.packages | xargs apt-get install -yqq --no-install-recommends \
    && pip install --no-cache-dir --prefer-binary -r /tools.test.requirements.txt \
    # Clean up
    && grep -v '^#' /odoo.adhoc.build.packages | xargs apt-get purge -yqq \
    && apt-get -yqq autoremove \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# GEOIP
COPY --from=geo-ip --chown=$ODOO_USER:$ODOO_USER /GeoIP $RESOURCES/GeoIP

# Entrypoint
WORKDIR "/home/odoo"
ENTRYPOINT ["/home/odoo/.resources/entrypoint.sh"]
CMD ["odoo"]
USER odoo
