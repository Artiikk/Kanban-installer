# Kanban CLI installer

Public host for the Kanban / `bcc-vibe` CLI installer scripts. The scripts carry
no secrets — the release archives are published here as GitHub Releases and are fetched
at install time.

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

Overrides: `VIBE_REPO` (default `Artiikk/Kanban-installer`), `VIBE_INSTALL_DIR`.

> Canonical source for these scripts lives in `frontend/scripts/` of the main
> repo; keep this mirror in sync when they change.
