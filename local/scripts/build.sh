#!/bin/bash
# Unified build script for NullClaw local examples

set -e

# Load utilities
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

show_help() {
    echo "NullClaw Local Examples Build Script"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --all           Build all examples (default)"
    echo "  --nullclaw      Build only NullClaw core"
    echo "  --modal-matrix  Build only modal-matrix example"
    echo "  --meshrelay-irc Build only meshrelay-irc example"
    echo "  --edge-worker   Build only edge-worker example"
    echo "  --target TRIPLE Cross-compile for target triple (e.g. x86_64-linux-musl)"
    echo "  --help          Show this help message"
}

BUILD_ALL=true
BUILD_NULLCLAW=false
BUILD_MODAL_MATRIX=false
BUILD_MESHRELAY_IRC=false
BUILD_EDGE_WORKER=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            BUILD_ALL=true
            shift
            ;;
        --nullclaw)
            BUILD_ALL=false
            BUILD_NULLCLAW=true
            shift
            ;;
        --modal-matrix)
            BUILD_ALL=false
            BUILD_MODAL_MATRIX=true
            shift
            ;;
        --meshrelay-irc)
            BUILD_ALL=false
            BUILD_MESHRELAY_IRC=true
            shift
            ;;
        --edge-worker)
            BUILD_ALL=false
            BUILD_EDGE_WORKER=true
            shift
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

log_info "Starting build process..."

if $BUILD_ALL || $BUILD_NULLCLAW; then
    build_nullclaw "$TARGET"
fi

if $BUILD_ALL || $BUILD_MODAL_MATRIX; then
    log_info "Building modal-matrix example..."
    cd "$LOCAL_ROOT/examples/modal-matrix" || exit 1
    if [[ -f "build.zig" ]]; then
        zig build -Doptimize=ReleaseSmall
    fi
    log_success "modal-matrix example built"
fi

if $BUILD_ALL || $BUILD_MESHRELAY_IRC; then
    log_info "Building meshrelay-irc example..."
    cd "$LOCAL_ROOT/examples/meshrelay-irc" || exit 1
    if [[ -f "build.zig" ]]; then
        zig build -Doptimize=ReleaseSmall
    fi
    log_success "meshrelay-irc example built"
fi

if $BUILD_ALL || $BUILD_EDGE_WORKER; then
    log_info "Building edge-worker example..."
    cd "$REPO_ROOT/examples/edge/cloudflare-worker" || exit 1
    log_info "Building WASM core..."
    zig build -Doptimize=ReleaseSmall -Dtarget=wasm32-wasi
    cp zig-out/bin/agent_core.wasm "$LOCAL_ROOT/examples/edge-worker/agent_core.wasm"

    cd "$LOCAL_ROOT/examples/edge-worker" || exit 1
    log_info "Installing Node.js dependencies..."
    if [[ -f "package.json" ]]; then
        npm install --production
    fi
    log_success "edge-worker example built"
fi

log_success "All requested builds completed successfully!"
