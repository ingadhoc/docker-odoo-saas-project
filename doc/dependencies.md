# Common dependencies

## Python (pip)

```py
# Used by autoaggregate script
git-aggregator==2.1.0
# ¿dev tool?
ipython==8.7.0

```

### algoliasearch

algoliasearch esta fija en al version 2.6.2. la version 4.12 es incompatible con [enterprise-extensions](https://github.com/ingadhoc/enterprise-extensions/). Se quiere depreciar la funcionalidad.

## Packages (APT)

```sh
# Usamos psql como ayuda de contexto (para inicialziar una base nueva, y tareas de mantenimiento y backup)
postgresql-client-15
# Used by gitagreggator
git
```
