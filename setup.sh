#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"
GITCONFIG="$HOME/.gitconfig"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# --- Collect identity details ---

echo "=== Git Multi-Identity Setup ==="
echo ""
echo "How many Git identities do you want to configure?"
read -rp "Number of identities (e.g., 2): " identity_count

if ! [[ "$identity_count" =~ ^[0-9]+$ ]] || [ "$identity_count" -lt 1 ]; then
    echo "Error: please enter a positive number."
    exit 1
fi

declare -a names emails labels directories hosts

for ((i = 1; i <= identity_count; i++)); do
    echo ""
    echo "--- Identity $i ---"
    read -rp "Label (e.g., work, personal): " label
    read -rp "Git user name: " name
    read -rp "Git email: " email
    read -rp "Git host (e.g., github.com, gitlab.com) [github.com]: " host
    host="${host:-github.com}"
    read -rp "Base directory for repos [~/workspace/$label]: " dir
    dir="${dir:-$HOME/workspace/$label}"
    dir="${dir/#\~/$HOME}"

    labels+=("$label")
    names+=("$name")
    emails+=("$email")
    hosts+=("$host")
    directories+=("$dir")
done

echo ""
read -rp "Default Git user name (used outside identity directories): " default_name
read -rp "Default Git email: " default_email

echo ""
echo "=== Review ==="
echo "Default identity: $default_name <$default_email>"
for ((i = 0; i < identity_count; i++)); do
    echo "  [$((i+1))] ${labels[$i]}: ${names[$i]} <${emails[$i]}> → ${directories[$i]} (${hosts[$i]})"
done
echo ""
read -rp "Proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

# --- Generate SSH keys ---

echo ""
echo "=== Generating SSH Keys ==="

for ((i = 0; i < identity_count; i++)); do
    label="${labels[$i]}"
    email="${emails[$i]}"
    key_path="$SSH_DIR/id_ed25519_$label"

    if [ -f "$key_path" ]; then
        echo "Key already exists: $key_path (skipping)"
    else
        ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
        echo "Created: $key_path"
    fi
done

# --- Start SSH agent and add keys ---

echo ""
echo "=== Adding Keys to SSH Agent ==="

eval "$(ssh-agent -s)"

for ((i = 0; i < identity_count; i++)); do
    label="${labels[$i]}"
    key_path="$SSH_DIR/id_ed25519_$label"
    ssh-add --apple-use-keychain "$key_path"
    echo "Added to agent and Keychain: $key_path"
done

# --- Configure SSH config ---

echo ""
echo "=== Configuring SSH ==="

ssh_config="$SSH_DIR/config"
touch "$ssh_config"
chmod 600 "$ssh_config"

for ((i = 0; i < identity_count; i++)); do
    label="${labels[$i]}"
    host="${hosts[$i]}"
    alias="$host-$label"
    key_path="$SSH_DIR/id_ed25519_$label"

    if grep -q "Host $alias" "$ssh_config" 2>/dev/null; then
        echo "SSH alias '$alias' already exists in config (skipping)"
    else
        cat >> "$ssh_config" <<EOF

# ${label} account
Host $alias
    HostName $host
    User git
    IdentityFile $key_path
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
EOF
        echo "Added SSH alias: $alias"
    fi
done

# --- Create per-identity git configs ---

echo ""
echo "=== Configuring Git ==="

for ((i = 0; i < identity_count; i++)); do
    label="${labels[$i]}"
    name="${names[$i]}"
    email="${emails[$i]}"
    config_file="$HOME/.gitconfig-$label"

    if [ -f "$config_file" ]; then
        git config -f "$config_file" user.name "$name"
        git config -f "$config_file" user.email "$email"
        echo "Updated: $config_file"
    else
        cat > "$config_file" <<EOF
[user]
    name = $name
    email = $email
EOF
        echo "Created: $config_file"
    fi
done

# --- Create repo directories ---

for ((i = 0; i < identity_count; i++)); do
    dir="${directories[$i]}"
    mkdir -p "$dir"
    echo "Ensured directory exists: $dir"
done

# --- Configure main .gitconfig with includeIf ---

git config --global user.name "$default_name"
git config --global user.email "$default_email"

for ((i = 0; i < identity_count; i++)); do
    dir="${directories[$i]}"
    [[ "$dir" != */ ]] && dir="$dir/"
    label="${labels[$i]}"

    include_key="includeIf.gitdir:${dir}.path"
    include_val="~/.gitconfig-$label"

    if git config --global --get "$include_key" "$include_val" >/dev/null 2>&1; then
        echo "includeIf for '$dir' already exists (skipping)"
    else
        git config --global --add "$include_key" "$include_val"
        echo "Added includeIf for: $dir → .gitconfig-$label"
    fi
done

echo "Updated: $GITCONFIG"

# --- Print public keys ---

echo ""
echo "=== Setup Complete ==="
echo ""
echo "=========================================="
echo "  IMPORTANT: Copy your public keys to"
echo "  your Git hosting accounts NOW!"
echo "=========================================="
echo ""
echo "Steps:"
echo "  1. Copy the public key shown below for each identity"
echo "  2. Go to your Git hosting account:"
echo "     - GitHub:    Settings > SSH and GPG keys > New SSH key"
echo "     - GitLab:    Preferences > SSH Keys > Add new key"
echo "     - Bitbucket: Personal settings > SSH keys > Add key"
echo "  3. Paste the key and save"
echo ""
echo "Your setup will NOT work until the keys are added!"
echo ""
for ((i = 0; i < identity_count; i++)); do
    label="${labels[$i]}"
    host="${hosts[$i]}"
    key_path="$SSH_DIR/id_ed25519_$label.pub"
    echo "--- ${label} (add to your $host account) ---"
    cat "$key_path"
    echo ""
done

read -rp "Press Enter once you've added the keys to continue..."

echo ""
echo "Test your connections:"
for ((i = 0; i < identity_count; i++)); do
    echo "  ssh -T git@${hosts[$i]}-${labels[$i]}"
done
echo ""
echo "=== Usage Examples ==="
echo ""
echo "Clone a repo:"
for ((i = 0; i < identity_count; i++)); do
    echo "  git clone git@${hosts[$i]}-${labels[$i]}:org/repo.git ${directories[$i]}/repo"
done
echo ""
echo "Checkout, add, commit, push:"
for ((i = 0; i < identity_count; i++)); do
    echo "  cd ${directories[$i]}/repo"
    echo "  git checkout -b feature/my-branch"
    echo "  git add ."
    echo "  git commit -m \"Your commit message\""
    echo "  git push origin feature/my-branch"
    echo ""
done
echo "Update remote URL on an existing repo:"
for ((i = 0; i < identity_count; i++)); do
    echo "  cd ${directories[$i]}/existing-repo"
    echo "  git remote set-url origin git@${hosts[$i]}-${labels[$i]}:org/existing-repo.git"
done
echo ""
echo "Your identity (name/email) is applied automatically based on the directory."
