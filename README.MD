# README

## Para hacer el build en local

GITHUB_BOT_TOKEN ver en dockerhub
SAAS_PROVIDER_TOKEN  ver en dockerhub
BASE_IMAGE_TAG=17.0

```sh
export DOCKER_BUILDKIT=1 \
    && docker build --no-cache \
    -t adhoc/odoo-adhoc:17.3-dev \
    --build-arg BASE_IMAGE_REPO=adhoc/odoo \
    --build-arg BASE_IMAGE_TAG=17.0-dev \
    --build-arg GITHUB_BOT_TOKEN= \
    --build-arg SAAS_PROVIDER_TOKEN= \
    --build-arg SAAS_PROVIDER_URL=https://www.adhoc.com.ar \
    --build-arg DOCKER_IMAGE=adhoc/odoo-adhoc \
    -f Dockerfile .
# docker push adhoc/odoo-adhoc:17.0-dev
```
