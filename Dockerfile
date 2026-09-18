# IRIS project starter — Dockerfile
# Use the base image as-is until your project needs something more. Uncomment
# sections below as those needs arise; each is independent of the others.

ARG IMAGE=intersystemsdc/iris-community:2026.1
FROM $IMAGE

# --- OS packages ---
# USER root
# RUN apt-get update && apt-get install -y --no-install-recommends curl \
#     && rm -rf /var/lib/apt/lists/*
# USER ${ISC_PACKAGE_MGRUSER}

# --- Embedded Python packages ---
# Install as root BEFORE switching back to the IRIS user — the embedded
# Python site-packages directory is not writable by the non-root user.
# USER root
# RUN ${ISC_PACKAGE_INSTALLDIR}/bin/irispython -m pip install --no-cache-dir \
#     pandas requests
# USER ${ISC_PACKAGE_MGRUSER}

# --- Windows/WSL2 first-boot fix ---
# Docker Desktop on WSL2 can crash IRIS's docker_setup_namespace() bootstrap
# on first start. Pre-creating iris.init avoids it.
# RUN touch ${ISC_PACKAGE_INSTALLDIR}/iris.init

# --- Copy source / config ---
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} src/ /irisdev/app/src/
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} config/merge.cpf /tmp/merge.cpf
# RUN iris start IRIS && iris merge IRIS /tmp/merge.cpf && iris stop IRIS quietly

# --- ZPM module install (BI/Interoperability projects) ---
# Local module (module.xml in this repo) — note the class is %IPM.Main on this
# image's IPM version, not the older %ZPM.PackageManager:
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} module.xml /tmp/module/
# RUN iris start IRIS && \
#     iris session IRIS -U%SYS "##class(%IPM.Main).Shell(\"load /tmp/module -verbose\")" && \
#     iris stop IRIS quietly

# Registry modules (published to the IPM registry, no local source needed) —
# list module names in the appropriate loop below, one loop per target
# namespace. %SYS is fine for modules that only register a web app (e.g.
# bi-export-plus); anything with a post-install Invoke step that touches
# data/globals (e.g. samples-bi's HoleFoods.Utils.StopJournalling) assumes
# the current *namespace* name is also a *database* name, which breaks with
# <INVALID OREF> in %SYS (whose database is "IRISSYS", not "%SYS") — install
# those into USER instead, where the namespace and its default database
# share the same name. When in doubt, dry-run the install first (see
# CLAUDE.md) rather than trusting a green `docker compose build`.
# RUN iris start IRIS && \
#     for MODULE in samples-bi; do \
#         iris session IRIS -UUSER "##class(%IPM.Main).Shell(\"install ${MODULE} -verbose\")"; \
#     done && \
#     for MODULE in bi-export-plus; do \
#         iris session IRIS -U%SYS "##class(%IPM.Main).Shell(\"install ${MODULE} -verbose\")"; \
#     done && \
#     iris stop IRIS quietly
