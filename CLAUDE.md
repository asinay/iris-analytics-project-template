# CLAUDE.md

Guidance for Claude Code when working in a project started from this template.

## What This Template Is

A minimal Docker + VS Code starting point for InterSystems IRIS projects — `docker-compose.yml`,
`Dockerfile`, `.env.example`, `.vscode/`, `.devcontainer/`. It has no application code of its own;
projects cloned from it add their own `src/`, ObjectScript classes, or Python code on top.

## IRIS Tooling: Use iris-agentic-dev, Not Raw docker exec

This project wires Claude Code to **iris-agentic-dev**, an MCP server that gives direct tool access
to the running IRIS container — compile ObjectScript, run SQL, inspect globals, run unit tests,
inspect productions — without shelling out to `docker exec` or hand-rolling REST calls.

- Upstream: https://github.com/intersystems-community/iris-agentic-dev
- Fork used here: https://github.com/asinay/iris-agentic-dev
- MCP config: `.claude/mcp.json` (already wired to the `iris` service in `docker-compose.yml` via
  `host.docker.internal` + the ports/credentials in `.env`)

Prefer its tools (`iris_query`, `iris_compile`, `iris_execute`, `check_config`, etc.) over manual
`docker exec`/`curl` against the Atelier REST API. Run `check_config` first if a connection isn't
working — it resolves and reports the connection source without touching the network.

On Windows, iris-agentic-dev's native binary isn't signed yet, so it runs via the Docker image
(`ghcr.io/intersystems-community/iris-agentic-dev:latest`) as configured in `.claude/mcp.json` — not
a locally installed binary.

**`.claude/mcp.json`'s `${IRIS_PASSWORD:-SYS}`-style defaults read the OS environment, not this
project's `.env` file** — docker-compose loads `.env` automatically, but Claude Code's MCP config
expansion doesn't. If you set a real `IRIS_PASSWORD` in `.env`, either `export` it in your shell
before starting Claude Code, or edit the default directly in `.claude/mcp.json`.

## Docker Conventions Used Here (don't drift from these)

- Image tag is pinned explicitly (currently `2026.1`) — never `:latest`. Community images already
  bundle ZPM; don't add a `-zpm` tag suffix.
- Env vars: `IRIS_PASSWORD`, `IRIS_USERNAME`, `IRIS_PORT`, `IRIS_SUPER_PORT`. Don't introduce
  `IRIS_USER` or other variants.
- `${ISC_PACKAGE_MGRUSER}` / `${ISC_PACKAGE_IRISGROUP}` / `${ISC_PACKAGE_INSTALLDIR}` are used
  instead of hardcoded names like `irisowner` — they resolve correctly across IRIS versions.
- Embedded Python packages install via `${ISC_PACKAGE_INSTALLDIR}/bin/irispython -m pip` as **root**,
  before switching back to the IRIS user. Installing after the user switch fails silently on
  read-only site-packages — this bit a prior project, don't repeat it.
- The commented-out WSL2 fix in the Dockerfile (`touch ${ISC_PACKAGE_INSTALLDIR}/iris.init`) exists
  because IRIS's first-boot bootstrap can crash under Docker Desktop + WSL2. Uncomment it if `docker
  compose up` fails on first run on Windows.
- **Never install IPM/ZPM modules into `%SYS`** — install into `USER` (or another namespace whose
  default database shares its name). `%SYS`'s database is `IRISSYS`, not `%SYS`, and modules that
  assume namespace name == database name (e.g. `samples-bi`'s post-install step) fail fast with
  `<INVALID OREF>` there and never populate data. Modules that only register a web app *compile*
  fine in `%SYS`, but they still end up isolated from any BI cube/pivot data that other modules put
  in `USER` — so treat this as a blanket rule, not a case-by-case judgment call.
- Before wiring an unfamiliar ZPM/IPM module into the Dockerfile's registry-module loop, dry-run
  `##class(%IPM.Main).Shell("install <name> -verbose")` in a running container first if it has a
  post-install `Invoke` step (check its `module.xml`). `docker compose build` succeeding only proves
  the shell command exited 0 — IPM/ZPM `Activate` failures print `ERROR!` but don't fail the build.
  `scripts/verify.sh` automates this dry-run (build, boot, check every module actually installed and
  every embedded Python package actually imports, then tear down) — run it instead of doing this by
  hand after touching the Dockerfile's module or package lists.

## Local Dev

```bash
cp .env.example .env          # fill in IRIS_PASSWORD
docker compose up -d
docker compose logs -f        # watch for "IRIS startup complete"
docker compose down -v        # clean up including volumes
```

There is no build system or test runner beyond the IRIS container itself — this repo is
infrastructure, not application code.

### Avoiding port collisions across multiple projects cloned from this template

`IRIS_PORT`/`IRIS_SUPER_PORT` both default to the standard `52773`/`1972` in `.env.example`, and
`.claude/mcp.json` reads whichever values end up in this project's own `.env` — so two projects
started at the same time on one machine will collide on the default ports unless one of them uses
different values. Before the first `docker compose up -d` in a new project, check whether the
defaults are already taken (`docker ps --format "{{.Ports}}"` or just try it — Docker's error is
`port is already allocated`) and, if so, pick unused ones for that project's `.env` (e.g. `52774`/
`1973`) before starting. `mcp.json` picks up the change automatically since it reads the same `.env`.
