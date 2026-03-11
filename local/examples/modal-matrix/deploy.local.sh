#!/bin/bash
# Local deployment script for modal-matrix example

set -e

source ../../scripts/utils.sh

show_help() {
    echo "Modal-Matrix Local Deployment Script"
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  init      Initialize Matrix homeserver and create users"
    echo "  start     Start all services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  status    Show service status"
    echo "  logs      Show service logs"
    echo "  destroy   Destroy all data and services"
}

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

COMMAND=$1

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

case $COMMAND in
    init)
        log_info "Initializing Matrix homeserver..."
        mkdir -p data/synapse data/postgres data/agent-coordinator data/agent-worker

        # Generate Synapse config
        if [[ ! -f data/synapse/homeserver.yaml ]]; then
            docker run -it --rm \
                -v "$(pwd)/data/synapse:/data" \
                -e SYNAPSE_SERVER_NAME=matrix.local \
                -e SYNAPSE_REPORT_STATS=no \
                matrixdotorg/synapse:latest generate
        fi

        # Start services
        docker-compose up -d synapse synapse-db
        log_info "Waiting for Synapse to start..."
        sleep 30

        # Create users
        log_info "Creating coordinator user..."
        docker exec -it nullclaw-matrix-synapse register_new_matrix_user \
            -c /data/homeserver.yaml \
            -u coordinator \
            -p coordinator_password \
            -a http://localhost:8008 \
            --no-admin

        log_info "Creating worker user..."
        docker exec -it nullclaw-matrix-synapse register_new_matrix_user \
            -c /data/homeserver.yaml \
            -u worker \
            -p worker_password \
            -a http://localhost:8008 \
            --no-admin

        log_info "Creating admin user..."
        docker exec -it nullclaw-matrix-synapse register_new_matrix_user \
            -c /data/homeserver.yaml \
            -u admin \
            -p admin_password \
            -a http://localhost:8008 \
            --admin

        # Get access tokens
        log_info "Getting access tokens..."
        COORDINATOR_TOKEN=$(curl -s -X POST http://localhost:8008/_matrix/client/v3/login \
            -H "Content-Type: application/json" \
            -d '{"type":"m.login.password","user":"coordinator","password":"coordinator_password"}' | \
            jq -r '.access_token')

        WORKER_TOKEN=$(curl -s -X POST http://localhost:8008/_matrix/client/v3/login \
            -H "Content-Type: application/json" \
            -d '{"type":"m.login.password","user":"worker","password":"worker_password"}' | \
            jq -r '.access_token')

        # Create room
        log_info "Creating general room..."
        ROOM_ID=$(curl -s -X POST http://localhost:8008/_matrix/client/v3/createRoom \
            -H "Authorization: Bearer $COORDINATOR_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"name":"General","room_alias_name":"general","preset":"public_chat"}' | \
            jq -r '.room_id')

        # Invite worker to room
        curl -s -X POST "http://localhost:8008/_matrix/client/v3/rooms/$ROOM_ID/invite" \
            -H "Authorization: Bearer $COORDINATOR_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"user_id":"@worker:matrix.local"}'

        # Join room as worker
        curl -s -X POST "http://localhost:8008/_matrix/client/v3/rooms/$ROOM_ID/join" \
            -H "Authorization: Bearer $WORKER_TOKEN" \
            -H "Content-Type: application/json"

        # Save .env file
        cat > .env << EOF
COORDINATOR_ACCESS_TOKEN=$COORDINATOR_TOKEN
WORKER_ACCESS_TOKEN=$WORKER_TOKEN
MATRIX_ROOM_ID=$ROOM_ID
EOF

        log_success "Initialization completed! Check .env file for credentials."
        log_info "Next steps: Run '$0 start' to start all agents."
        ;;

    start)
        docker-compose up -d
        log_success "All services started successfully!"
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

    destroy)
        log_warn "This will delete ALL data! Are you sure? (y/N)"
        read -r confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            docker-compose down -v
            rm -rf data .env
            log_success "All data destroyed successfully!"
        else
            log_info "Operation cancelled."
        fi
        ;;

    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
