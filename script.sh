#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"

info() {
    printf "\e[34m[INFO]\e[0m %s\n" "$1"
}

success() {
    printf "\e[32m[SUCCESS]\e[0m %s\n" "$1"
}

error() {
    printf "\e[31m[ERROR]\e[0m %s\n" "$1" >&2
}

is_package_installed() {
    dpkg -s "$1" &> /dev/null
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${ID,,}" != "ubuntu" ]]; then
            error "Unsupported operating system: $NAME. This script is intended for Ubuntu."
            exit 1
        elif [[ "${VERSION_ID,,}" != "22.04" && "${VERSION_ID,,}" != "20.04" ]]; then
            error "Unsupported operating system version: $VERSION. This script is intended for Ubuntu 20.04 or 22.04."
            exit 1
        else
            info "Operating System: $PRETTY_NAME"
        fi
    else
        error "/etc/os-release not found. Unable to determine the operating system."
        exit 1
    fi
}

update_system() {
    info "Updating and upgrading the system packages..."
    sudo apt update -y | tee -a "$LOG_FILE"
    sudo apt upgrade -y | tee -a "$LOG_FILE"
    success "System packages updated and upgraded successfully."
}

install_packages() {
    local packages=(
        nvtop
        ubuntu-drivers-common
        build-essential
        libssl-dev
        curl
        gnupg
        ca-certificates
        lsb-release
        jq
    )

    info "Installing essential packages: ${packages[*]}..."
    sudo apt install -y "${packages[@]}" | tee -a "$LOG_FILE"
    success "Essential packages installed successfully."
}

install_gpu_drivers() {
    info "Checking for existing NVIDIA GPU driver..."

    # Check if NVIDIA driver module is already loaded
    if lsmod | grep -q "^nvidia"; then
        success "NVIDIA driver is already loaded in the kernel. Skipping installation."
        return 0
    fi

    # Optional: check via nvidia-smi (if available)
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            success "NVIDIA driver is already installed and functional. Skipping installation."
            return 0
        fi
    fi

    info "Detecting recommended GPU driver..."
    local driver
    driver=$(ubuntu-drivers devices 2>/dev/null | awk '/recommended/ {print $3}')

    if [ -z "$driver" ]; then
        error "No recommended GPU driver found."
        return 1
    fi

    if is_package_installed "$driver"; then
        info "GPU driver package ($driver) is already installed. Skipping installation."
    else
        info "Installing GPU driver package: $driver"
        if sudo apt-get install -y "$driver" 2>&1 | tee -a "$LOG_FILE"; then
            success "GPU driver ($driver) installed successfully."
        else
            error "Failed to install GPU driver ($driver)."
            return 1
        fi
    fi
}

install_rust() {
    if command -v rustc &> /dev/null; then
        info "Rust is already installed. Skipping Rust installation."
    else
        info "Installing Rust programming language..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y | tee -a "$LOG_FILE"
        
        if [[ -f "$HOME/.cargo/env" ]]; then
            source "$HOME/.cargo/env"
            success "Rust installed successfully."
        else
            error "Rust installation failed. ~/.cargo/env not found."
            exit 1
        fi
    fi
    
    info "Configuring Rust environment for all users and sessions..."
    
    if ! grep -q 'source $HOME/.cargo/env' ~/.bashrc 2>/dev/null; then
        echo 'source $HOME/.cargo/env' >> ~/.bashrc
    fi
    
    if ! grep -q 'source $HOME/.cargo/env' ~/.profile 2>/dev/null; then
        echo 'source $HOME/.cargo/env' >> ~/.profile
    fi
    
    if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
        local user_home="/home/$SUDO_USER"
        if ! sudo -u "$SUDO_USER" grep -q 'source $HOME/.cargo/env' "$user_home/.bashrc" 2>/dev/null; then
            echo 'source $HOME/.cargo/env' | sudo -u "$SUDO_USER" tee -a "$user_home/.bashrc" > /dev/null
        fi
        if ! sudo -u "$SUDO_USER" grep -q 'source $HOME/.cargo/env' "$user_home/.profile" 2>/dev/null; then
            echo 'source $HOME/.cargo/env' | sudo -u "$SUDO_USER" tee -a "$user_home/.profile" > /dev/null
        fi
    fi
    
    export PATH="$HOME/.cargo/bin:$PATH"
    success "Rust environment configured for current and future sessions."
}

install_just() {
    if command -v just &>/dev/null; then
        info "'just' is already installed. Skipping."
        return
    fi

    info "Installing the 'just' command-runner..."
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | sudo bash -s -- --to /usr/local/bin | tee -a "$LOG_FILE"
    success "'just' installed successfully."
}

install_cuda() {
    if is_package_installed "cuda-toolkit"; then
        info "CUDA Toolkit is already installed. Skipping CUDA installation."
    else
        info "Installing CUDA Toolkit and dependencies..."
        local distribution
        distribution=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"'| tr -d '\.')
        info "Installing Nvidia CUDA keyring and repo"
        wget https://developer.download.nvidia.com/compute/cuda/repos/$distribution/$(/usr/bin/uname -m)/cuda-keyring_1.1-1_all.deb 2>&1 | tee -a "$LOG_FILE"
        sudo dpkg -i cuda-keyring_1.1-1_all.deb 2>&1 | tee -a "$LOG_FILE"
        rm cuda-keyring_1.1-1_all.deb
        sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
        sudo apt-get install -y cuda-toolkit 2>&1 | tee -a "$LOG_FILE"
        success "CUDA Toolkit installed successfully."
    fi
}

install_docker() {
    if command -v docker &> /dev/null; then
        info "Docker is already installed. Skipping Docker installation."
    else
        info "Installing Docker..."
        sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common 2>&1 | tee -a "$LOG_FILE"

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>&1 | tee -a "$LOG_FILE"

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update -y 2>&1 | tee -a "$LOG_FILE"

        sudo apt install -y docker-ce docker-ce-cli containerd.io 2>&1 | tee -a "$LOG_FILE"

        sudo systemctl enable docker 2>&1 | tee -a "$LOG_FILE"

        sudo systemctl start docker 2>&1 | tee -a "$LOG_FILE"

        success "Docker installed and started successfully."
    fi
}

add_user_to_docker_group() {
    local username
    username=$(logname 2>/dev/null || echo "$SUDO_USER")

    if ! getent group docker >/dev/null; then
        info "Creating 'docker' group..."
        sudo groupadd docker
    fi

    if id -nG "$username" | grep -qw "docker"; then
        info "User '$username' is already in the 'docker' group."
    else
        info "Adding user '$username' to the 'docker' group..."
        sudo usermod -aG docker "$username" 2>&1 | tee -a "$LOG_FILE"
        success "User '$username' added to the 'docker' group."
        info "To apply the new group membership, please log out and log back in."
    fi
}

install_nvidia_container_toolkit() {
    info "Checking NVIDIA Container Toolkit installation..."

    if is_package_installed "nvidia-docker2"; then
        success "NVIDIA Container Toolkit (nvidia-docker2) is already installed."
        configure_docker_nvidia_runtime
        return
    fi

    info "Installing NVIDIA Container Toolkit..."

    local distribution
    distribution=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - 2>&1 | tee -a "$LOG_FILE"
    curl -s -L https://nvidia.github.io/nvidia-docker/"$distribution"/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list 2>&1 | tee -a "$LOG_FILE"

    sudo apt update -y 2>&1 | tee -a "$LOG_FILE"

    # Set non-interactive mode and install nvidia-docker2 without prompts
    export DEBIAN_FRONTEND=noninteractive
    echo 'nvidia-docker2 nvidia-docker2/daemon.json boolean false' | sudo debconf-set-selections
    sudo -E apt install -y nvidia-docker2 2>&1 | tee -a "$LOG_FILE"

    # Configure Docker daemon after installation
    configure_docker_nvidia_runtime

    sudo systemctl restart docker 2>&1 | tee -a "$LOG_FILE"

    success "NVIDIA Container Toolkit installed successfully."
}

configure_docker_nvidia_runtime() {
    info "Configuring Docker daemon for NVIDIA runtime..."
    
    sudo mkdir -p /etc/docker
    
    if [[ -f /etc/docker/daemon.json ]]; then
        info "Backing up existing daemon.json..."
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%s)
    fi
    
    # Create the proper daemon.json configuration
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

    success "Docker daemon configured for NVIDIA runtime."
}

cleanup() {
    info "Cleaning up unnecessary packages..."
    sudo apt autoremove -y 2>&1 | tee -a "$LOG_FILE"
    sudo apt autoclean -y 2>&1 | tee -a "$LOG_FILE"
    success "Cleanup completed."
}

init_git_submodules() {
    info "ensuring submodules are initialized..."
    git submodule update --init --recursive 2>&1 | tee -a "$LOG_FILE"
    success "git submodules initialized successfully"
}

verify_rust_installation() {
    info "Verifying Rust installation..."
    if command -v rustc &> /dev/null && command -v cargo &> /dev/null; then
        local rust_version=$(rustc --version)
        local cargo_version=$(cargo --version)
        success "Rust verification successful: $rust_version"
        success "Cargo verification successful: $cargo_version"
    else
        error "Rust verification failed. Commands not available in current session."
        exit 1
    fi
}

verify_docker_nvidia() {
    info "Verifying Docker with NVIDIA support..."
    if sudo docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi &> /dev/null; then
        success "Docker with NVIDIA support verified successfully."
    else
        info "NVIDIA Docker test skipped (GPU may not be available or drivers not loaded yet)."
    fi
}

info "===== Script Execution Started at $(date) ====="

check_os

init_git_submodules

update_system

install_packages

install_gpu_drivers

install_docker

add_user_to_docker_group

install_nvidia_container_toolkit

install_rust

verify_rust_installation

install_just

install_cuda

cleanup

verify_docker_nvidia

success "All tasks completed successfully!"

info "===== Script Execution Ended at $(date) ====="

exit 0
