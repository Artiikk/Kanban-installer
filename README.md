# Kanban CLI installer

Public host for the BccVibe / Kanban CLI installer scripts. The scripts carry
no secrets — the release archives live in the **private** repo
[`Artiikk/BCC-Vibe-Kanban`](https://github.com/Artiikk/BCC-Vibe-Kanban) and are
fetched with GitHub auth at install time.

## macOS / Linux

```bash
# Auth once (preferred):
gh auth login
curl -fsSL https://raw.githubusercontent.com/Artiikk/Kanban-installer/main/install.sh | bash

# …or pass a PAT with repo read access (also needs jq):
BCC_VIBE_TOKEN=<github-pat> bash -c "$(curl -fsSL https://raw.githubusercontent.com/Artiikk/Kanban-installer/main/install.sh)"
```

## Windows (PowerShell)

```powershell
$env:BCC_VIBE_TOKEN = "<github-pat>"
irm https://raw.githubusercontent.com/Artiikk/Kanban-installer/main/install.ps1 | iex
```

Overrides: `BCC_VIBE_REPO` (default `Artiikk/BCC-Vibe-Kanban`), `BCC_VIBE_INSTALL_DIR`.

> Canonical source for these scripts lives in `frontend/scripts/` of the main
> repo; keep this mirror in sync when they change.
