# IRIS Project Template

Minimal Docker + VS Code starting point for new InterSystems IRIS projects. Click **Use this template**
on GitHub (once this repo is pushed) to start a new project from it, or copy the folder directly.

## Quick Start

```bash
cp .env.example .env          # fill in IRIS_PASSWORD
docker compose up -d
docker compose logs -f        # watch for "IRIS startup complete"
```

Open the folder in VS Code and reopen in the dev container (`.devcontainer/`), or connect the
ObjectScript extension directly using the server profile already defined in `.vscode/settings.json`.

```bash
docker compose down -v        # clean up including volumes
```

## What's Included

- `docker-compose.yml` — pinned IRIS Community image, named volume, healthcheck, `.env`-driven ports
- `Dockerfile` — commented opt-in blocks for OS packages, embedded Python, a WSL2 first-boot fix,
  source/config copy, and ZPM module install. Uncomment only what your project needs.
- `.vscode/` — ObjectScript server connection + recommended extensions
- `.devcontainer/` — VS Code dev container wired to the same compose file
- `.claude/mcp.json` + `CLAUDE.md` — wires Claude Code to [iris-agentic-dev](https://github.com/intersystems-community/iris-agentic-dev),
  an MCP server that gives it direct tools against the running IRIS container (query, compile,
  run tests) instead of raw `docker exec`/REST calls
- `scripts/verify.sh` — builds the image and smoke-tests it (healthy boot, every IPM module actually
  installed, every embedded Python package actually importable) under its own throwaway compose
  project, then tears itself down

## Adding Python Packages or ZPM/IPM Modules

The Dockerfile's blocks are commented out on purpose — this section is the missing "how":

1. In `docker-compose.yml`, comment out `image: ...` and uncomment `build: .` — Docker Compose
   only reads the Dockerfile when told to build.
2. In `Dockerfile`, uncomment the relevant block (embedded Python packages, or the ZPM/IPM
   registry-module loop) and fill in package/module names.
3. `docker compose build && docker compose up -d` (or just `docker compose up -d --build`).

Never install ZPM/IPM modules into `%SYS` — always `USER` (or another namespace whose default
database shares its name). `%SYS`'s database is `IRISSYS`, not `%SYS`; modules that assume
namespace name == database name (e.g. `samples-bi`'s post-install step) fail with `<INVALID OREF>`
there, and even ones that don't end up isolated from any BI cube/pivot data other modules put in
`USER`. Dry-run an unfamiliar module in a running container before trusting a green build — see
`CLAUDE.md`'s note on why (`docker compose build` succeeding doesn't mean the module's install
actually worked). `scripts/verify.sh` automates this dry-run: it builds, boots the container,
confirms every module in the Dockerfile's install loop is actually listed by IPM and every embedded
Python package actually imports, then tears itself down — run it after touching either list instead
of checking by hand.

## Design Notes

Extracted from patterns and pitfalls across several real IRIS projects:

- Embedded Python packages must be installed via `${ISC_PACKAGE_INSTALLDIR}/bin/irispython -m pip`
  as **root**, before switching to the IRIS user — its site-packages directory isn't writable otherwise.
- Community images already bundle ZPM; no `-zpm` image tag suffix is needed.
- `${ISC_PACKAGE_MGRUSER}` / `${ISC_PACKAGE_IRISGROUP}` / `${ISC_PACKAGE_INSTALLDIR}` are used instead of
  hardcoded names like `irisowner`, since they resolve correctly across IRIS versions.
- On Windows/WSL2, IRIS's first-boot `docker_setup_namespace()` step can crash; pre-creating
  `iris.init` at build time avoids it (commented block in the Dockerfile).
- Env vars are named `IRIS_PASSWORD` / `IRIS_USERNAME` / `IRIS_PORT` / `IRIS_SUPER_PORT` consistently —
  other projects have drifted between `IRIS_USER` and `IRIS_USERNAME`.

## Variants Not Included Here

These showed up in real projects but are situational enough to leave out of the default template.
Add them to the Dockerfile/compose above when a project actually needs them:

- **JDBC connectivity** (`jaydebeapi` + JDBC jar) instead of embedded Python — requires a JVM via JPype
  and needs row-by-row decoding of `LONGVARCHAR` columns.
- **Web Gateway** for a separate reverse-proxy front end.
- **GitHub Actions CI** for build/test on push.
- **Deploying this to a remote test box** (e.g. a cloud VM) — SSH/provisioning automation for a
  remote host is its own concern, not IRIS/Docker, so it belongs in a separate repo rather than here.
