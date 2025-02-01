# Notes

We use act to test the workflow, please install it.

[+info](https://nektosact.com/installation/index.html)

Intalation as github cli extension.

```sh
gh extension install https://github.com/nektos/gh-act
```

## Run

```sh

export SAAS_PROVIDER_URL="https://example.com"
export SAAS_PROVIDER_TOKEN=mysecretotocken
export ODOO_VERSION="18.0"
export MAXMIND_LICENSE_KEY=myothersecretotocken
export MAXMIND_LICENSE_USR=userid
export GITHUB_BOT_TOKEN=anothersecretotocken
export DOCKER_USERNAME=mydockeruser
export DOCKER_PASSWORD=secretdockerpassword
```

```sh
gh act workflow_dispatch \
 --input odoo_target="18.0" \
 -s DOCKER_USERNAME=$DOCKER_USERNAME \
 -s DOCKER_PASSWORD=$DOCKER_PASSWORD \
 -s MAXMIND_LICENSE_USR=$MAXMIND_LICENSE_USR \
 -s MAXMIND_LICENSE_KEY=$MAXMIND_LICENSE_KEY \
 -s SAAS_PROVIDER_URL=$SAAS_PROVIDER_URL \
 -s SAAS_PROVIDER_TOKEN=$SAAS_PROVIDER_TOKEN \
 -s BOT_TOKEN_GITHUB=$GITHUB_BOT_TOKEN
```

```sh
docker buildx build \
    --secret id=MAXMIND_LICENSE_KEY,env=MAXMIND_LICENSE_KEY \
    --secret id=MAXMIND_LICENSE_USR,env=MAXMIND_LICENSE_USR  \
    --secret id=SAAS_PROVIDER_URL,env=SAAS_PROVIDER_URL \
    --secret id=SAAS_PROVIDER_TOKEN,env=SAAS_PROVIDER_TOKEN \
    --secret id=GITHUB_BOT_TOKEN,env=GITHUB_BOT_TOKEN \
    --build-arg ODOO_VERSION="18.0" \
    --target dev \
    -t "dev" \
    .
```
