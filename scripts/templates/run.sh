#!/usr/bin/env bash
#
# Veda server launcher — CANONICAL TEMPLATE.
#
# This file is the source of truth for the `run.sh` that ships inside the
# veda-server-linux-x86_64.tar.gz tarball. When building a new release,
# copy this file into the staging directory so the bundled launcher matches
# what docs/server.md describes.
#
# Behavior:
#   - On first run, creates ~/.local/veda-server/.venv and installs the
#     bundled wheel into it. This sidesteps PEP 668 on Ubuntu 22.04+ where
#     `pip install --system` is refused by the externally-managed Python.
#   - On subsequent runs, just execs the server from the existing venv.
#   - All arguments are forwarded to the server. Pass --host / --port to
#     control where it binds; env vars like VEDA_ROUTER_HOST aren't honored.
#
# The bundled wheel only exposes `veda-admin` as a console script — the
# server entry point is `python -m veda_router.server`, not a `veda-router`
# binary. Don't try to invoke a `veda-router` shim.
set -euo pipefail

cd "$(dirname "$0")"
VENV="$(pwd)/.venv"

if [ ! -f "${VENV}/bin/python" ] || ! "${VENV}/bin/python" -c "import veda_router" >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    uv venv "${VENV}" >/dev/null
    uv pip install --python "${VENV}/bin/python" *.whl >/dev/null
  else
    python3 -m venv "${VENV}"
    "${VENV}/bin/pip" install --quiet *.whl
  fi
fi

exec "${VENV}/bin/python" -m veda_router.server "$@"
