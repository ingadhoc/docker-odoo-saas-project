#!/bin/bash

set -e
set -x

if ! command -v curl &> /dev/null; then
    INSTALLED_BY_SCRIPT=true
    apt-get install -yqq --no-install-recommends curl
fi

WKHTMLTOPDF_VERSION=0.12.5
WKHTMLTOPDF_CHECKSUM='1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb'

curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.stretch_amd64.deb
echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c -
apt-get install -yqq --no-install-recommends ./libjpeg-turbo8.deb
rm -Rf wkhtmltox.deb

if [ "$INSTALLED_BY_SCRIPT" = true ]; then
    apt-get purge -yqq curl
fi
