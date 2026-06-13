# Kanban CLI installer

Public host for the Kanban / `bcc-vibe` CLI installer scripts. The scripts carry
no secrets — the release archives live in the **private** repo
[`Artiikk/BCC-Vibe-Kanban`](https://github.com/Artiikk/BCC-Vibe-Kanban) and are
fetched with GitHub auth at install time.

## macOS / Linux

```bash
# Auth once (preferred):
gh auth login
curl -fsSL https://raw.githubusercontent.com/Artiikk/Kanban-installer/main/install.sh | bash
```

## Windows (PowerShell)

```powershell
$env:VIBE_TOKEN = "<github-pat>"
irm https://raw.githubusercontent.com/Artiikk/Kanban-installer/main/install.ps1 | iex
```

Auth: a logged-in `gh` CLI (no env needed), or `VIBE_TOKEN` set to a GitHub PAT
with `repo` read access (`GITHUB_TOKEN`/`GH_TOKEN` also work). The token path
needs `jq`. Downloads are verified against `checksums.txt` before install.

Overrides: `VIBE_REPO` (default `Artiikk/BCC-Vibe-Kanban`), `VIBE_INSTALL_DIR`.

> Canonical source for these scripts lives in `frontend/scripts/` of the main
> repo; keep this mirror in sync when they change.
