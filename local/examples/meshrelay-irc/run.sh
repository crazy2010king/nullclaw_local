#!/bin/bash
# Run script for meshrelay-irc example

set -e

source ../../scripts/utils.sh

show_help() {
    echo "MeshRelay IRC Example Run Script"
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start     Start IRC bot and local IRC server"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show service status"
    echo "  logs      Show service logs"
    echo "  console   Attach to IRC console"
}

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

COMMAND=$1

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
mkdir -p data/ircd data/bot

case $COMMAND in
    start)
        log_info "Starting MeshRelay IRC example..."
        check_docker
        check_docker_compose

        # Start local IRC server (InspIRCd)
        docker-compose up -d ircd
        log_info "Waiting for IRC server to start..."
        sleep 10

        # Register bot nickname with NickServ
        log_info "Registering bot nickname..."
        docker exec -it nullclaw-irc-server inspircd --config /inspircd/conf/inspircd.conf \
            --command "NICKSERV REGISTER nullclaw-bot nickserv_password_here bot@meshrelay.local"

        # Start NullClaw bot
        docker-compose up -d bot
        log_success "MeshRelay IRC example started successfully!"
        log_info "IRC server: irc://localhost:6697 (TLS) / irc://localhost:6667 (plaintext)"
        log_info "Bot nickname: nullclaw-bot"
        log_info "Channels: #general, #tech, #support"
        ;;

    stop)
        docker-compose down
        log_success "All services stopped successfully!"
        ;;

    restart)
        docker-compose restart
        log_success "All services restarted successfully!"
        ;;

    status)
        docker-compose ps
        ;;

    logs)
        docker-compose logs -f
        ;;

    console)
        log_info "Attaching to IRC console (Ctrl+C to exit)..."
        if command -v weechat &> /dev/null; then
            weechat -r "/server add meshrelay localhost/6667 -ssl -autoconnect -autojoin #general"
        else
            log_warn "weechat not installed, using netcat as fallback..."
            nc localhost 6667
        fi
        ;;

    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
