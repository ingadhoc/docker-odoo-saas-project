# Workflows

## Basic explains

The "base" image will be rebuilt at least once a month. To force the rebuild of this layer within that timeframe, you can increase the value of `odoo_build_force`

Additionally, the "Odoo by Adhoc" images will be rebuilt every time an action is triggered.

## Trigger via webhook

```sh
curl -X POST \
  -H "Authorization: token YOUR_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{
    "event_type": "webhook",
    "client_payload": {
      "odoo_target": "18.0"
    }
  }'
```

## Act

[Download](https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz)

## Secrets

### Github

### Docker hub

Used to upload the final images

DOCKER_USERNAME=
DOCKER_PASSWORD=

### GeoIP

Used to download GeoIp DB

MAXMIND_LICENSE_USR=
MAXMIND_LICENSE_KEY=

### GITHUB_BOT

Used to download gitaggregate sources

BOT_TOKEN_GITHUB

required permissions:

- read repositories (dev-adhoc and ingadhoc)

### ODOO SAAS PROVIDER

Used to report git HEADS during image builds and used for send message from users

SAAS_PROVIDER_TOKEN=
SAAS_PROVIDER_URL="https://example.com"
