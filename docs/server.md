# Self-hosted Veda server

The server component is the FastAPI router that drives the Veda app: WebSocket
dispatch, conversation storage, model routing, federation. It is the back end —
the mobile/desktop client points at it.

## Install

```bash
curl -fsSL https://rishavchatterjee.com/veda/install.sh | VEDA_COMPONENT=server bash
```

Note the env var placement — it must be on `bash`, not `curl`. Putting
`VEDA_COMPONENT=server` before `curl` exports it only into curl's environment;
the script run by the right-hand `bash` would default back to `desktop`.

The installer lands the tree at `~/.local/veda-server/`. Only Linux is packaged
for the server today; macOS and Windows server builds are not on the roadmap.

## Config

All runtime state lives under `~/.veda/`:

| File                  | Owner              | Notes                                  |
| --------------------- | ------------------ | -------------------------------------- |
| `conversations.db`    | dispatch           | turns, vector clocks                   |
| `users.db`            | auth               | per-device users                       |
| `user_settings.db`    | preferences        | role / preset / source overrides       |
| `user_models.db`      | model registry     | per-user uploaded weights              |
| `federation.db`       | federation         | paired peers                           |

Override any path with the matching env var (`VEDA_ROUTER_CONV_DB`,
`VEDA_ROUTER_USERS_DB`, etc.) when you need to run multiple instances on one
host.

## Run

```bash
~/.local/veda-server/run.sh
```

`run.sh` installs the bundled wheel (via `uv pip install` if `uv` is on PATH,
otherwise `python3 -m pip install --user`) and then execs `veda-router serve`.
Subsequent runs are quick because pip skips already-installed packages.

Defaults to `0.0.0.0:8080`. Override host/port with `--host` and `--port`, or
set `VEDA_ROUTER_HOST` / `VEDA_ROUTER_PORT`.

## systemd unit

`~/.config/systemd/user/veda-router.service`:

```ini
[Unit]
Description=Veda router (self-hosted)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/veda-server/run.sh
Restart=on-failure
RestartSec=5s
Environment=VEDA_ROUTER_HOST=0.0.0.0
Environment=VEDA_ROUTER_PORT=8080

[Install]
WantedBy=default.target
```

Enable and start:

```bash
systemctl --user daemon-reload
systemctl --user enable --now veda-router.service
journalctl --user -u veda-router -f
```

## The 8 pillars and your server

The server is **SOVEREIGN** by design: hot paths make zero external calls. Local
models run on local hardware, federated peers talk over your LAN or Tailscale,
and all stores are SQLite on disk. The installer never reaches out beyond
GitHub for the artifact itself — once installed, the binary will not phone home.

If you wire up cloud LLM providers, OTP delivery, or other external services,
they sit outside the hot path and behind explicit circuit breakers
(`RESILIENT`), and any keys live in your local config — never in the binary.
