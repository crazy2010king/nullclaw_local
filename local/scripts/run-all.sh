#!/bin/bash
# Unified run script for all NullClaw local examples

set -e

# Load utilities
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

show_help() {
    echo "NullClaw Local Examples Run Script"
    echo "Usage: $0 [COMMAND] [EXAMPLE]"
    echo
    echo "Commands:"
    echo "  start    Start example(s)"
    echo "  stop     Stop example(s)"
    echo "  restart  Restart example(s)"
    echo "  status   Show status of example(s)"
    echo "  logs     Show logs of example(s)"
    echo
    echo "Examples (optional, default: all):"
    echo "  modal-matrix  Modal + Matrix multi-agent example"
    echo "  meshrelay-irc MeshRelay IRC integration example"
    echo "  edge-worker   Edge computing WASM example"
    echo "  all           Run command on all examples (default)"
}

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

COMMAND=$1
EXAMPLE=${2:-all}

validate_command() {
    case $COMMAND in
        start|stop|restart|status|logs)
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

run_command() {
    local example=$1
    local dir="$LOCAL_ROOT/examples/$example"

    if [[ ! -d "$dir" ]]; then
        log_error "Example $example does not exist"
        return 1
    fi

    case $COMMAND in
        start)
            start_service "$example" "$dir"
            ;;
        stop)
            stop_service "$example" "$dir"
            ;;
        restart)
            stop_service "$example" "$dir"
            start_service "$example" "$dir"
            ;;
        status)
            service_status "$example" "$dir"
            ;;
        logs)
            service_logs "$example" "$dir"
            ;;
    esac
}

validate_command

log_info "Running $COMMAND command on $EXAMPLE example(s)"

if [[ "$EXAMPLE" == "all" ]]; then
    # Check dependencies for all examples
    check_docker
    check_docker_compose
    check_nodejs

    run_command "modal-matrix"
    run_command "meshrelay-irc"
    run_command "edge-worker"
else
    # Check dependencies for specific example
    case $EXAMPLE in
        modal-matrix|meshrelay-irc)
            check_docker
            check_docker_compose
            ;;
        edge-worker)
            check_nodejs
            check_docker
            check_docker_compose
            ;;
    esac

    run_command "$EXAMPLE"
fi

log_success "Command $COMMAND completed successfully!"
