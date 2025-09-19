#!/bin/bash
# Utility functions for managing VM global packages

function install_conda_globally() {
    local group_owner="${1:-root}"

    # shellcheck disable=SC2155
    local installer="Miniforge3-$(uname)-$(uname -m).sh"
    curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/$installer"

    sudo bash "$installer" -b -p /opt/conda

    # shellcheck disable=SC2016
    echo 'export PATH=$PATH:/opt/conda/bin' | sudo tee /etc/profile.d/conda.sh
    sudo chmod +x /etc/profile.d/conda.sh

    sudo tee /opt/conda/.condarc >/dev/null <<'EOF'
pkgs_dirs:
  - /opt/conda/pkgs
envs_dirs:
  - ~/scratch/.conda/envs
auto_activate_base: false
EOF

    sudo chown -R root:root /opt/conda
    sudo chmod -R a+rX /opt/conda

    sudo mkdir -p /opt/conda/pkgs
    sudo chown -R root:"$group_owner" /opt/conda/pkgs
    sudo chmod -R 2775 /opt/conda/pkgs
    
    rm -f "$installer"

    echo "Conda installed globally in /opt/conda."
    echo "Shared package cache at /opt/conda/pkgs (group: $group_owner)."
    echo "User environments will default to ~/scratch/.conda/envs."
    echo "Reload your shell or run: source /etc/profile.d/conda.sh"
}

function install_pypoetry_globally() {
    local group_owner="${1:-root}"

    local install_dir="/opt/poetry"
    local cache_dir="/opt/poetry/cache"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "Python3 not found. Installing..."
        sudo apt update
        sudo apt install -y python3 python3-venv python3-pip
    fi

    curl -sSL https://install.python-poetry.org | sudo env POETRY_HOME="$install_dir" python3 -

    sudo chown -R root:"$group_owner" "$install_dir"
    sudo chmod -R 755 "$install_dir"

    sudo mkdir -p "$cache_dir"
    sudo chown -R root:"$group_owner" "$cache_dir"
    sudo chmod -R 2775 "$cache_dir"

    sudo tee /etc/profile.d/poetry.sh >/dev/null <<EOF
export PATH=\$PATH:$install_dir/bin
export POETRY_CACHE_DIR=$cache_dir
EOF
    sudo chmod +x /etc/profile.d/poetry.sh

    echo "Poetry installed globally in $install_dir."
    echo "Global Poetry cache: $cache_dir (group: $group_owner)."
    echo "Reload your shell or run: source /etc/profile.d/poetry.sh"
}

function install_uv_globally() {
    local group_owner="${1:-root}"

    local install_dir="/opt/uv"
    local cache_dir="/opt/uv/cache"
    local python_install_dir="/opt/uv/python"
    local python_bin_dir="/opt/uv/bin"

    curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="$install_dir" sh

    sudo chown -R root:"$group_owner" "$install_dir"
    sudo chmod -R 755 "$install_dir"

    sudo mkdir -p "$cache_dir"
    sudo chown -R root:"$group_owner" "$cache_dir"
    sudo chmod -R 2775 "$cache_dir"

    sudo mkdir -p "$python_install_dir"
    sudo chown -R root:"$group_owner" "$python_install_dir"
    sudo chmod -R 2775 "$python_install_dir"

    sudo mkdir -p "$python_bin_dir"
    sudo chown -R root:"$group_owner" "$python_install_dir"
    sudo chmod -R 2775 "$python_install_dir"

    sudo tee /etc/profile.d/uv.sh >/dev/null <<EOF
export PATH=$install_dir:\$PATH
export UV_CACHE_DIR=$cache_dir
export UV_PYTHON_INSTALL_DIR=$python_install_dir
export UV_PYTHON_BIN_DIR=$python_bin_dir
EOF
    sudo chmod +x /etc/profile.d/uv.sh

    echo "uv installed globally in $install_dir."
    echo "Shared cache: $cache_dir"
    echo "Reload your shell or run: source /etc/profile.d/uv.sh"
}