# Managing Multiple Git Identities

## Overview

This project provides a setup script to configure multiple Git identities (e.g., Work and Personal) on a single machine using SSH keys and Git's `includeIf` directive.

## How It Works

The setup combines two mechanisms:

1. **SSH Config** — separate SSH keys per account, with host aliases to route to the correct key.
2. **Git `includeIf`** — automatically switches `user.name` and `user.email` based on the repository's directory location.

## Directory Convention

Repos are organized by identity under a base directory:

```
~/workspace/work/       → uses work git config
~/workspace/personal/   → uses personal git config
```

## Files Modified by setup.sh

| File | Purpose |
|---|---|
| `~/.ssh/id_ed25519_<identity>` | SSH private key per identity |
| `~/.ssh/id_ed25519_<identity>.pub` | SSH public key per identity |
| `~/.ssh/config` | Host aliases mapping identity → key |
| `~/.gitconfig` | Main git config with `includeIf` rules |
| `~/.gitconfig-<identity>` | Per-identity git config (name + email) |

## Clone URLs

When using SSH aliases, clone URLs change:

```
# Instead of:
git@github.com:org/repo.git

# Use the alias:
git@github.com-work:org/repo.git
git@github.com-personal:org/repo.git
```

## Usage Examples

### Clone a repository

```bash
# Work repo — use the github.com-work alias
git clone git@github.com-work:my-company/project.git ~/workspace/work/project

# Personal repo — use the github.com-personal alias
git clone git@github.com-personal:myuser/side-project.git ~/workspace/personal/side-project
```

### Checkout, add, commit, push

Once cloned into the correct directory, all standard Git commands work as usual — the identity is applied automatically.

```bash
# Work example
cd ~/workspace/work/project
git checkout -b feature/new-api
echo "hello" > file.txt
git add file.txt
git commit -m "Add file"
git push origin feature/new-api

# Personal example
cd ~/workspace/personal/side-project
git checkout -b fix/typo
echo "fixed" > README.md
git add README.md
git commit -m "Fix typo"
git push origin fix/typo
```

### Update remote URL on an existing repo

If you already cloned a repo with the default `github.com` host, update the remote to use the alias:

```bash
cd ~/workspace/work/existing-repo
git remote set-url origin git@github.com-work:my-company/existing-repo.git
```

## Verification

```bash
# Check identity in a repo directory
cd ~/workspace/work/some-repo
git config user.email    # should show work email

# Test SSH connection
ssh -T git@github.com-work
ssh -T git@github.com-personal
```
