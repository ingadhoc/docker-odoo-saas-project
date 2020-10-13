ARG FROM_DOCKER_REPO
ARG FROM_DOCKER_TAG
FROM $FROM_DOCKER_REPO:$FROM_DOCKER_TAG
USER root

# Save some usefull env variables
ARG GITHUB_USER
ARG GITHUB_TOKEN
ARG GITLAB_USER
ARG GITLAB_TOKEN
# TODO: Analyze if it's a good idea to store these as environment variables
# For security reasons, it may be better to send them at runtime
# During build, we don't need them. We only need the ARGs
ENV GITHUB_USER=${GITHUB_USER} \
    GITHUB_TOKEN=${GITHUB_TOKEN} \
    GITLAB_USER=${GITLAB_USER} \
    GITLAB_TOKEN=${GITLAB_TOKEN}

# Custom SaaS build files
# TODO: This could be refactored so that it uses the tools provided by the parent image
ARG SAAS_PROVIDER_URL
ARG SAAS_PROVIDER_TOKEN
ARG DOCKER_REPO
ARG DOCKER_TAG_SUFFIX
COPY resources/$ODOO_VERSION/*   $RESOURCES/
COPY saas_build_image $RESOURCES/saas_build_image
RUN chmod a+x $RESOURCES/saas_build_image && $RESOURCES/saas_build_image

USER odoo
