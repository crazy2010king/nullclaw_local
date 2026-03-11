#!/bin/bash
# Unified test script for all NullClaw local examples

set -e

# Load utilities
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

show_help() {
    echo "NullClaw Local Examples Test Script"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --all           Run all tests (default)"
    echo "  --unit          Run only unit tests"
    echo "  --integration   Run only integration tests"
    echo "  --performance   Run only performance tests"
    echo "  --example NAME  Test only specific example"
    echo "  --help          Show this help message"
}

TEST_ALL=true
TEST_UNIT=false
TEST_INTEGRATION=false
TEST_PERFORMANCE=false
EXAMPLE_FILTER="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            TEST_ALL=true
            shift
            ;;
        --unit)
            TEST_ALL=false
            TEST_UNIT=true
            shift
            ;;
        --integration)
            TEST_ALL=false
            TEST_INTEGRATION=true
            shift
            ;;
        --performance)
            TEST_ALL=false
            TEST_PERFORMANCE=true
            shift
            ;;
        --example)
            EXAMPLE_FILTER="$2"
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

log_info "Starting test process..."

# Run core unit tests first
if $TEST_ALL || $TEST_UNIT; then
    log_info "Running core NullClaw unit tests..."
    cd "$REPO_ROOT" || exit 1
    zig build test --summary all
    log_success "Core unit tests passed"
fi

test_example() {
    local example=$1
    local dir="$LOCAL_ROOT/examples/$example"

    if [[ ! -d "$dir" ]]; then
        log_error "Example $example does not exist"
        return 1
    fi

    log_info "Testing $example example..."
    cd "$dir" || exit 1

    if $TEST_ALL || $TEST_UNIT; then
        if [[ -f "build.zig" ]]; then
            log_info "Running $example unit tests..."
            zig build test --summary all
        fi
    fi

    if $TEST_ALL || $TEST_INTEGRATION; then
        log_info "Running $example integration tests..."
        if [[ -f "test.sh" ]]; then
            chmod +x test.sh
            ./test.sh
        elif [[ -f "docker-compose.yml" ]]; then
            log_info "Testing container health..."
            if command -v docker-compose &> /dev/null; then
                docker-compose up -d --wait
                docker-compose exec -T nullclaw /app/nullclaw status
                docker-compose down
            else
                docker compose up -d --wait
                docker compose exec -T nullclaw /app/nullclaw status
                docker compose down
            fi
        fi
    fi

    if $TEST_ALL || $TEST_PERFORMANCE; then
        log_info "Running $example performance tests..."
        if [[ -f "perf.sh" ]]; then
            chmod +x perf.sh
            ./perf.sh
        else
            # Default performance checks
            log_info "Checking binary size..."
            if [[ -f "zig-out/bin/nullclaw" ]]; then
                local size=$(du -h zig-out/bin/nullclaw | cut -f1)
                log_info "Binary size: $size"
                if [[ $(du -k zig-out/bin/nullclaw | cut -f1) -lt 1024 ]]; then
                    log_success "Binary size < 1MB: ✅"
                else
                    log_warn "Binary size > 1MB: ⚠️"
                fi
            fi

            log_info "Checking startup time..."
            if command -v hyperfine &> /dev/null; then
                hyperfine --warmup 3 "zig-out/bin/nullclaw --version"
            else
                time nullclaw --version
            fi
        fi
    fi

    log_success "$example example tests passed"
}

if [[ "$EXAMPLE_FILTER" == "all" ]]; then
    test_example "modal-matrix"
    test_example "meshrelay-irc"
    test_example "edge-worker"
else
    test_example "$EXAMPLE_FILTER"
fi

log_success "All requested tests completed successfully!"
