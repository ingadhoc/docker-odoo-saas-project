Only the resources for the built ODOO_VERSION are copied into the image.
These patches are not applied.

They have to be manually applied in the saas_provider.build script, like this:

Environment 1.0
---------------

Patches `server.py` to avoid creating a database automatically.

`$RESOURCES/apply_patch_1_0`


Environment 2.0
---------------

Patches `odoo` bin to add `ODOO_SAAS_PATH`.

`$RESOURCES/apply_patch_2_0`
