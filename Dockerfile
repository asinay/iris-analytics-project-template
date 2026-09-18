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
# openpyxl is required by bi-export-plus's .xlsx export path (see its
# AfterInstallMessage below).
USER root
RUN ${ISC_PACKAGE_INSTALLDIR}/bin/irispython -m pip install --no-cache-dir \
    openpyxl
USER ${ISC_PACKAGE_MGRUSER}

# --- Windows/WSL2 first-boot fix ---
# Docker Desktop on WSL2 can crash IRIS's docker_setup_namespace() bootstrap
# on first start. Pre-creating iris.init avoids it.
# RUN touch ${ISC_PACKAGE_INSTALLDIR}/iris.init

# --- Copy source / config ---
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} src/ /irisdev/app/src/
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} config/merge.cpf /tmp/merge.cpf
# RUN iris start IRIS && iris merge IRIS /tmp/merge.cpf && iris stop IRIS quietly

# --- ZPM module install (BI/Interoperability projects) ---
# Never install IPM/ZPM modules into %SYS (its database is "IRISSYS", not
# "%SYS" — modules that assume namespace name == database name fail with
# <INVALID OREF> there, and even ones that don't end up isolated from any BI
# cube/pivot data other modules put in USER). Install into USER instead.
#
# Local module (module.xml in this repo) — note the class is %IPM.Main on this
# image's IPM version, not the older %ZPM.PackageManager:
# COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} module.xml /tmp/module/
# RUN iris start IRIS && \
#     iris session IRIS -UUSER "##class(%IPM.Main).Shell(\"load /tmp/module -verbose\")" && \
#     iris stop IRIS quietly

# Registry modules (published to the IPM registry, no local source needed).
# All five below go into USER: samples-bi provides the BI cubes,
# analyzethis/pivotsubscriptions/thirdpartychartportlets build on top of
# them, and bi-export-plus's Analyzer export buttons need to see the same
# namespace's pivots (its module.xml registers its web app at
# NameSpace="${namespace}", i.e. wherever it's installed).
#
# Before adding a module here, dry-run it first (see CLAUDE.md) rather than
# trusting a green `docker compose build` — IPM/ZPM Activate failures print
# ERROR! but don't fail the build. `scripts/verify.sh` automates this: build,
# boot, confirm every module below actually installed and every embedded
# Python package actually imports, then tear down.
RUN iris start IRIS && \
    for MODULE in samples-bi analyzethis pivotsubscriptions thirdpartychartportlets bi-export-plus; do \
        iris session IRIS -UUSER "##class(%IPM.Main).Shell(\"install ${MODULE} -verbose\")"; \
    done && \
    iris stop IRIS quietly
