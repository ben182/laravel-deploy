#!/bin/bash

# Port Management System for Multiple Projects
# Automatically assigns unique ports to projects

PORT_REGISTRY="/home/$(whoami)/projects/.ports"
START_PORT=8000
MAX_PORT=8999

# Initialize port registry if it doesn't exist
init_registry() {
    if [ ! -f "$PORT_REGISTRY" ]; then
        mkdir -p "$(dirname "$PORT_REGISTRY")"
        echo "# Port Registry - Format: project_id:port" > "$PORT_REGISTRY"
    fi
}

# Get assigned port for a project
get_port() {
    local project_id="$1"
    init_registry
    
    # Check if project already has a port
    if grep -q "^$project_id:" "$PORT_REGISTRY"; then
        grep "^$project_id:" "$PORT_REGISTRY" | cut -d: -f2
        return 0
    fi
    
    # Find next available port
    local port=$START_PORT
    while [ $port -le $MAX_PORT ]; do
        if ! grep -q ":$port$" "$PORT_REGISTRY"; then
            # Port is available, assign it
            echo "$project_id:$port" >> "$PORT_REGISTRY"
            echo "$port"
            return 0
        fi
        ((port++))
    done
    
    echo "ERROR: No available ports in range $START_PORT-$MAX_PORT" >&2
    return 1
}

# Release port for a project
release_port() {
    local project_id="$1"
    init_registry
    
    if grep -q "^$project_id:" "$PORT_REGISTRY"; then
        sed -i "/^$project_id:/d" "$PORT_REGISTRY"
        echo "Port released for project: $project_id"
    else
        echo "No port found for project: $project_id"
    fi
}

# List all assigned ports
list_ports() {
    init_registry
    echo "Assigned ports:"
    grep -v "^#" "$PORT_REGISTRY" | while IFS=: read -r project port; do
        echo "  $project: $port"
    done
}

# Check if port is in use
is_port_in_use() {
    local port="$1"
    netstat -tuln | grep -q ":$port "
}

# Main function
main() {
    case "$1" in
        "get")
            get_port "$2"
            ;;
        "release")
            release_port "$2"
            ;;
        "list")
            list_ports
            ;;
        *)
            echo "Usage: $0 {get|release|list} [project_id]"
            echo "  get PROJECT_ID    - Get/assign port for project"
            echo "  release PROJECT_ID - Release port for project"
            echo "  list              - List all assigned ports"
            exit 1
            ;;
    esac
}

main "$@"