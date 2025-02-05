#!/bin/bash

set -e
set -x

# PG Client
apt-get install -yqq --no-install-recommends curl gnupg

echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' >> /etc/apt/sources.list.d/postgresql.list
curl -SL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get install -yqq --no-install-recommends postgresql-client-14
