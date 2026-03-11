#!/bin/bash
# Common utility functions for NullClaw local examples

# Logging functions
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Environment checks
check_zig_version() {
    if ! command -v zig &> /dev/null; then
        log_error "Zig is not installed. Please install Zig 0.15.2 first."
        exit 1
    fi

    local zig_version=$(zig version)
    if [[ "$zig_version" != "0.15.2" ]]; then
        log_error "Zig version $zig_version is not supported. Please install exactly Zig 0.15.2."
        exit 1
    fi
    log_success "Zig version $zig_version is valid."
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    log_success "Docker is available."
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    log_success "Docker Compose is available."
}

check_nodejs() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    local node_version=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [[ "$node_version" -lt 18 ]]; then
        log_error "Node.js version $node_version is not supported. Please install Node.js 18+."
        exit 1
    fi
    log_success "Node.js version $node_version is valid."
}

# Service management
start_service() {
    local name=$1
    local dir=$2
    log_info "Starting $name service..."
    cd "$dir" || {
        log_error "Directory $dir does not exist"
        return 1
    }

    if [[ -f "docker-compose.yml" ]]; then
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
        else
            docker compose up -d
        fi
    elif [[ -f "run.sh" ]]; then
        chmod +x run.sh
        ./run.sh start
    else
        log_error "No startup script found for $name"
        return 1
    fi
    log_success "$name service started successfully"
}

stop_service() {
    local name=$1
    local dir=$2
    log_info "Stopping $name service..."
    cd "$dir" || {
        log_error "Directory $dir does not exist"
        return 1
    }

    if [[ -f "docker-compose.yml" ]]; then
        if command -v docker-compose &> /dev/null; then
            docker-compose down
        else
            docker compose down
        fi
    elif [[ -f "run.sh" ]]; then
        chmod +x run.sh
        ./run.sh stop
    else
        log_error "No stop script found for $name"
        return 1
    fi
    log_success "$name service stopped successfully"
}

service_status() {
    local name=$1
    local dir=$2
    log_info "Checking $name service status..."
    cd "$dir" || {
        log_error "Directory $dir does not exist"
        return 1
    }

    if [[ -f "docker-compose.yml" ]]; then
        if command -v docker-compose &> /dev/null; then
            docker-compose ps
        else
            docker compose ps
        fi
    elif [[ -f "run.sh" ]]; then
        chmod +x run.sh
        ./run.sh status
    else
        log_error "No status script found for $name"
        return 1
    fi
}

service_logs() {
    local name=$1
    local dir=$2
    log_info "Showing $name service logs..."
    cd "$dir" || {
        log_error "Directory $dir does not exist"
        return 1
    }

    if [[ -f "docker-compose.yml" ]]; then
        if command -v docker-compose &> /dev/null; then
            docker-compose logs -f
        else
            docker compose logs -f
        fi
    elif [[ -f "run.sh" ]]; then
        chmod +x run.sh
        ./run.sh logs
    else
        log_error "No logs script found for $name"
        return 1
    fi
}

# Build functions
build_nullclaw() {
    local target=$1
    log_info "Building NullClaw..."
    check_zig_version
    cd "$REPO_ROOT" || exit 1

    if [[ -n "$target" ]]; then
        zig build -Doptimize=ReleaseSmall -Dtarget="$target"
    else
        zig build -Doptimize=ReleaseSmall
    fi

    if [[ $? -eq 0 ]]; then
        log_success "NullClaw built successfully"
        cp zig-out/bin/nullclaw "$REPO_ROOT/local/bin/" 2>/dev/null || true
    else
        log_error "NullClaw build failed"
        exit 1
    fi
}

# Environment variables
export REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export LOCAL_ROOT="$REPO_ROOT/local"
export PATH="$LOCAL_ROOT/bin:$PATH"

# Create bin directory if it doesn't exist
mkdir -p "$LOCAL_ROOT/bin"
