#!/bin/bash

set +x
set +e

# Issue: https://github.com/odoo/odoo/issues/187021
sed -i "s/gevent==21\.8\.0 ; sys_platform != 'win32' and python_version > '3\.9' and python_version <= '3\.10'  # (Jammy)/gevent==21.12.0 ; sys_platform != 'win32' and python_version > '3.9' and python_version <= '3.10'  # (Jammy)/" /odoo.requirements.txt

