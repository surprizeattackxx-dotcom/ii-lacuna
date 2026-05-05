#!/usr/bin/env bash

# Pre-flight check for ii-lacuna installation
# Validates basic environment requirements for a smooth setup.

echo -e "\033[1;36m[ii-lacuna] Running pre-flight system checks...\033[0m"

# 1. Check for basic utilities
REQUIRED_TOOLS=("git" "curl" "wget" "sudo")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "\033[0;31m[!] Missing dependency: $tool\033[0m"
        exit 1
    fi
done

# 2. Check Architecture
if [ "$(uname -m)" != "x86_64" ]; then
    echo -e "\033[0;31m[!] Unsupported architecture: $(uname -m). ii-lacuna targets x86_64.\033[0m"
    exit 1
fi

# 3. Check for /etc/os-release (for distro detection)
if [ ! -f /etc/os-release ]; then
    echo -e "\033[0;31m[!] Cannot detect distribution: /etc/os-release not found.\033[0m"
    exit 1
fi

echo -e "\033[0;32m[✓] System checks passed.\033[0m"
