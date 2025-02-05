#!/bin/bash

set -e
set -x

apt-get install -yqq --no-install-recommends curl
curl -sLo libjpeg-turbo8.deb http://mirrors.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.1.2-0ubuntu1_amd64.deb
curl -sLo wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt-get install -yqq --no-install-recommends
    ./libjpeg-turbo8.deb
    ./wkhtmltox.deb
apt-get purge -yqq curl
rm -Rf wkhtmltox.deb libjpeg-turbo8.deb