#!/usr/bin/env bash
#
# Helper script that generates new public/private GPG key pairs
#
# Usage:
#
# Generate a key for John Doe; you will be prompted for a passphrase
# gpg-gen.sh --name \"John Doe\" --email john@doe.com" --pass
#
# If you want to generate a key without password (insecure)
# gpg-gen.sh --name \"John Doe\" --email john@doe.com"
#

set -ueo pipefail

if ! command -v gpg; then
    echo "GPG2 not found. Install with"
    echo "MacOS: brew install gnupg2"
    echo "Ubuntu: sudo apt install gnupg2"
    echo "or other"
    echo
    exit 1
fi

_usage() {
    echo "You must specify a name and email for the key."
    echo
    echo "Usage: $0 --name \"John Doe\" --email john@doe.com"
    echo
    exit 1
}
if [[ $# -lt 4 ]]; then
    _usage
fi

# Load arguments
NAME=
EMAIL=
pass=
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --pass) pass="yes"; shift 1 ;;
        * ) echo "Invalid option $1"; _usage ;;
    esac
done

# Read password
PASS_HEADER="%no-protection"
if [[ -n "$pass" ]]; then
    read -s -r -p "Please enter a password for your GPG key: " PASS1
    echo
    read -s -r -p "Enter the password again: " PASS2
    echo
    if [[ "$PASS1" != "$PASS2" ]]; then
        echo "The passwords do not match."
        echo
        exit 1
    fi
    PASS_HEADER="Passphrase: $PASS1"
    echo
    echo "You will be prompted for a password by GPG"
    echo "Make sure you have configured your pinentry program in ~/.gnupg/gpg-agent.conf, e.g.:"
    echo "pinentry-program /usr/local/bin/pinentry-mac"
    echo "OR"
    echo "pinentry-program /usr/local/bin/pinentry-tty"
    echo
    echo "You may also need to:"
    echo "export GPG_TTY=\"$(tty)\""
    echo
fi

echo
echo "==> Generating a GPG key for $NAME <$EMAIL>..."

TMPFILE="$(mktemp)"
(
echo "%echo Generating a basic OpenPGP key"
echo "Key-Type: DSA"
echo "Key-Length: 1024"
echo "Subkey-Type: ELG-E"
echo "Subkey-Length: 1024"
echo "Name-Real: $NAME"
echo "Name-Comment: $NAME"
echo "Name-Email: $EMAIL"
echo "$PASS_HEADER"
echo "Expire-Date: 0"
echo "%commit"
) > "$TMPFILE"

# Operate in a temporary dir to avoid polluting your platform's keyring
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME

# Generate the key
gpg --batch --generate-key "$TMPFILE" && rm -f "$TMPFILE"

# Find the key's ID
GPG_KEY=$(gpg --list-secret-keys | grep -E '[A-Z0-9]{40}' | awk '{ print $1 }')

echo
echo "Exporting the GPG public and private keys for $NAME <$EMAIL>..."
echo "WARNING: KEEP THE SECRET KEY SAFE!"
echo

echo
gpg --armor --export "${GPG_KEY}"
echo
gpg --armor --export-secret-key "${GPG_KEY}"

# Cleanup
rm -rf "$GNUPGHOME"
