ARG BASE_IMAGE_REPO
ARG BASE_IMAGE_TAG

FROM $BASE_IMAGE_REPO:$BASE_IMAGE_TAG

ARG GITHUB_USER
ARG GITHUB_TOKEN
ARG GITHUB_BOT_TOKEN
ARG GITLAB_TOKEN
ARG DOCKER_IMAGE
ARG SAAS_PROVIDER_URL
ARG SAAS_PROVIDER_TOKEN
ENV GITHUB_USER="$GITHUB_USER"
ENV GITHUB_TOKEN="$GITHUB_TOKEN"
ENV GITHUB_BOT_TOKEN="$GITHUB_BOT_TOKEN"

# Default env values used by config generator
# TODO remove after no more customers on v13 and also remove them on 90-saas-client.conf
ENV FILESTORE_OPERATIONS_THREADS=3 \
    FILESTORE_COPY_HARD_LINK=True \
    ENABLE_REDIS=False \
    REDIS_HOST=localhost \
    REDIS_PORT=6379 \
    REDIS_DBINDEX=1 \
    REDIS_PASS=False

# Add new entrypoints and configs
COPY entrypoint.d/* $RESOURCES/entrypoint.d/
COPY conf.d/* $RESOURCES/conf.d/

# Add resources.
COPY resources/$ODOO_VERSION/* $RESOURCES/

ENV BASE_URL="${SAAS_PROVIDER_URL}/odoo_project"
ENV URL_SUFIX="?docker_image=${DOCKER_IMAGE}&major_version=${ODOO_VERSION}&token=${SAAS_PROVIDER_TOKEN}"

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
RUN autoaggregate --config "$RESOURCES/saas-odoo_project_repos.yml" --output $SOURCES/repositories
RUN autoaggregate --config "$RESOURCES/saas-odoo_project_version_repos.yml" --output $SOURCES/repositories

# Report to provider all repos HEADs
RUN find $SOURCES -name "*.git" -type d -execdir sh -c "pwd && echo , && git log -n 1 origin/${ODOO_VERSION} --pretty=format:\"%H\" && echo \;; " \; | xargs -n3 > /tmp/repo_heads.txt ; curl -X POST $BASE_URL/report_sha$URL_SUFIX\&minor_version=`date -u +%Y.%m.%d` -H "Content-Type: application/json" -H "Accept: application/json" -d "@/tmp/repo_heads.txt"

# Install odoo
RUN pip install --user --no-cache-dir -e $SOURCES/odoo

# apply patch for environment v2
RUN $RESOURCES/apply_patch_2_0
