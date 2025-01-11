# Workflows

## Act

[Download](https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz)

## Secrets

### Github

GITHUB_TOKEN

required permissions:

- write on ghcr.io

### Docker hub

Used to upload the final images

DOCKER_USERNAME=
DOCKER_PASSWORD=

### GeoIP

MAXMIND_LICENSE_USR=
MAXMIND_LICENSE_KEY=

### GITHUB_BOT

BOT_TOKEN_GITHUB

required permissions:

- read repositories (dev-adhoc and ingadhoc)

### GITHUB REGISTRY

TOKEN_GH_REGISTRY

required permissions:

- r/w/d package
