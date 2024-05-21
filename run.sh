#!/bin/bash

LATEST_GITLEAKS_VERSION="8.18.2"
CHECKSUM_URL="https://github.com/gitleaks/gitleaks/releases/download/v$LATEST_GITLEAKS_VERSION/gitleaks_${LATEST_GITLEAKS_VERSION}_checksums.txt"
CHECKSUM_FILE="/tmp/gitleaks/gitleaks_${LATEST_GITLEAKS_VERSION}_checksums.txt"

check_gitleaks_existence() {
    if command -v gitleaks &> /dev/null; then
        GITLEAKS_VERSION_INSTALLED=$(gitleaks version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [ $? -eq 0 ]; then
            echo "Gitleaks is installed: $GITLEAKS_VERSION_INSTALLED"
            if [ "$GITLEAKS_VERSION_INSTALLED" != "$LATEST_GITLEAKS_VERSION" ]; then
                read -p "A newer version of Gitleaks is available ($LATEST_GITLEAKS_VERSION). Do you want to update? (y/N): " response
                if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                    install_gitleaks
                else
                    echo "Skipping update."
                fi
            else
                echo "Gitleaks is up to date."
            fi
        else
            echo "Gitleaks command exists but returned an error. Attempting reinstallation."
            install_gitleaks
        fi
    else
        echo "Gitleaks is not installed. Attempting installation."
        install_gitleaks
    fi
}

get_system_architecture() {
    OS=$(uname -s)
    ARCH=$(uname -m)

    case "$OS" in
        Darwin)
            if [ "$ARCH" == "x86_64" ]; then
                ARCH="darwin_x64"
            elif [ "$ARCH" == "arm64" ]; then
                ARCH="darwin_arm64"
            fi
            ;;
        Linux)
            if [ "$ARCH" == "x86_64" ]; then
                ARCH="linux_x64"
            elif [[ "$ARCH" == "armv7"* ]]; then
                ARCH="linux_armv7"
            elif [ "$ARCH" == "arm64" ]; then
                ARCH="linux_arm64"
            elif [ "$ARCH" == "i686" ]; then
                ARCH="linux_x32"
            fi
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            if [ "$ARCH" == "x86_64" ]; then
                ARCH="windows_x64"
            elif [[ "$ARCH" == "armv7"* ]]; then
                ARCH="windows_armv7"
            elif [[ "$ARCH" == "armv6"* ]]; then
                ARCH="windows_armv6"
            elif [ "$ARCH" == "i686" ]; then
                ARCH="windows_x32"
            fi
            ;;
        *)
            echo "Unsupported operating system. Please install Gitleaks manually."
            exit 1
            ;;
    esac

    echo $ARCH
}

download_and_verify() {
    local file_url=$1
    local expected_checksum=$2
    local file_name=$(basename "$file_url")

    echo "Downloading $file_name to /tmp/gitleaks..."
    curl -L "$file_url" -o "/tmp/gitleaks/$file_name"

    echo "Verifying checksum..."
    local actual_checksum=$(sha256sum "/tmp/gitleaks/$file_name" | awk '{ print $1 }')

    if [ "$expected_checksum" != "$actual_checksum" ]; then
        echo "Checksum verification failed for $file_name"
        echo "Expected: $expected_checksum"
        echo "Actual: $actual_checksum"
        exit 1
    fi
}

install_gitleaks() {
    ARCH=$(get_system_architecture)
    INSTALL_DIR="/usr/local/bin"

    echo "Downloading checksum file to /tmp/gitleaks..."
    mkdir -p /tmp/gitleaks
    curl -L "$CHECKSUM_URL" -o "$CHECKSUM_FILE"

    DOWNLOAD_URL=""
    CHECKSUM=""

    while IFS= read -r line; do
        CHECKSUM_LINE=$(echo $line | awk '{ print $1 }')
        FILE_NAME=$(echo $line | awk '{ print $2 }')
        if [[ "$FILE_NAME" == *"$ARCH"* ]]; then
            DOWNLOAD_URL="https://github.com/gitleaks/gitleaks/releases/download/v$LATEST_GITLEAKS_VERSION/$FILE_NAME"
            CHECKSUM=$CHECKSUM_LINE
            break
        fi
    done < "$CHECKSUM_FILE"

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "No suitable download found for architecture $ARCH"
        exit 1
    fi

    download_and_verify "$DOWNLOAD_URL" "$CHECKSUM"

    FILE_NAME=$(basename "$DOWNLOAD_URL")
    if [[ "$FILE_NAME" == *.tar.gz ]]; then
        tar -xzf "/tmp/gitleaks/$FILE_NAME" -C /tmp/gitleaks gitleaks
        sudo mv "/tmp/gitleaks/gitleaks" "$INSTALL_DIR"
    elif [[ "$FILE_NAME" == *.zip ]]; then
        unzip "/tmp/gitleaks/$FILE_NAME" -d /tmp/gitleaks
        mkdir -p ~/bin/
        mv /tmp/gitleaks/gitleaks.exe ~/bin/gitleaks.exe
    fi

    if command -v gitleaks &> /dev/null; then
        GITLEAKS_VERSION_INSTALLED=$(gitleaks version 2>&1)
        echo "Gitleaks installed successfully: $GITLEAKS_VERSION_INSTALLED"
    else
        echo "An error occurred while installing Gitleaks."
        exit 1
    fi
}

# Call the function to perform the check and install if necessary
check_gitleaks_existence

PRE_COMMIT_CONTENT=$(cat << 'EOF'
#!/usr/bin/env python3
"""Helper script to be used as a pre-commit hook."""
import sys
import subprocess

def gitleaksEnabled():
    """Determine if the pre-commit hook for gitleaks is enabled."""
    out = subprocess.getoutput("git config --bool hooks.gitleaks")
    if out == "false":
        return False
    return True

if gitleaksEnabled():
    exitCode = subprocess.run(['gitleaks', 'protect', '-v', '--staged'], capture_output=True, text=True).returncode
    if exitCode == 1:
        print('''Warning: gitleaks has detected sensitive information in your changes.
To disable the gitleaks precommit hook run the following command:

    git config hooks.gitleaks false
''')
        sys.exit(1)
else:
    print('gitleaks precommit disabled (enable with `git config hooks.gitleaks true`)')
EOF
)

if [ -d ".git" ]; then
    echo "$PRE_COMMIT_CONTENT" > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "pre-commit hook installed successfully."
else
    echo "No .git folder found. Skipping installation of pre-commit hook."
fi
