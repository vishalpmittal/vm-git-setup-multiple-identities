# Git Setup: Multiple Identities

Interactive shell script to configure multiple Git identities (e.g., work + personal) on one machine using per-identity SSH keys and Git's `includeIf` directive.

## Quick Start

```bash
./setup.sh
```

The script will prompt you for each identity's name, email, and GitHub account, then configure SSH keys, host aliases, and directory-based git configs.

## How It Works

- **SSH host aliases** route each identity to its own key (`~/.ssh/id_ed25519_<identity>`)
- **Git `includeIf`** auto-switches `user.name`/`user.email` based on repo directory (e.g., `~/workspace/work/` vs `~/workspace/personal/`)

## Usage

Clone using the host alias instead of `github.com`:

```bash
git clone git@github.com-work:org/repo.git ~/workspace/work/repo
git clone git@github.com-personal:myuser/project.git ~/workspace/personal/project
```

Once cloned into the correct directory, all standard Git commands work as usual — the identity is applied automatically:

```bash
cd ~/workspace/work/repo
git checkout -b feature/my-feature
git add .
git commit -m "Add feature"
git push origin feature/my-feature
```
