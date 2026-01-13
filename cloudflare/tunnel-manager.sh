#!/bin/bash
# Cloudflare Tunnel Management Helper
# Works across different deployment methods: systemd, docker, standalone

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detect how cloudflared is running
detect_cloudflared() {
    echo "🔍 Detecting cloudflared deployment method..."
    echo ""

    # Check systemd service
    if systemctl list-units --full --all 2>/dev/null | grep -q "cloudflared"; then
        print_status "Found systemd service"
        return 1
    fi

    # Check docker container
    if docker ps 2>/dev/null | grep -q cloudflare; then
        print_status "Found Docker container"
        return 2
    fi

    # Check docker-compose
    if docker compose ps 2>/dev/null | grep -q cloudflare; then
        print_status "Found Docker Compose service"
        return 3
    fi

    # Check standalone process
    if pgrep -f cloudflared > /dev/null 2>&1; then
        print_status "Found standalone process"
        return 4
    fi

    print_error "No cloudflared instance detected"
    return 0
}

# Restart systemd service
restart_systemd() {
    local service_name="$1"

    print_info "Restarting systemd service: $service_name"

    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        print_warning "Sudo access required. You may be prompted for password."
    fi

    echo ""
    echo "Commands to execute on the host system:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  sudo systemctl restart $service_name"
    echo "  sudo systemctl status $service_name"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Try to restart if we're on the host
    if [ -f "/run/systemd/system" ]; then
        sudo systemctl restart "$service_name"
        sudo systemctl status "$service_name" --no-pager
    else
        print_warning "Not running on host with systemd. Please execute above commands on the host."
    fi
}

# Restart docker container
restart_docker() {
    local container_name="$1"

    print_info "Restarting Docker container: $container_name"

    if command -v docker &> /dev/null; then
        docker restart "$container_name"
        docker ps --filter "name=$container_name"
    else
        print_error "Docker command not available in this environment"
        echo ""
        echo "On the host system, run:"
        echo "  docker restart $container_name"
    fi
}

# Restart docker-compose service
restart_compose() {
    print_info "Restarting Docker Compose service"

    cd "$PROJECT_DIR"

    if command -v docker &> /dev/null; then
        docker compose restart cloudflare-tunnel
        docker compose ps
    else
        print_error "Docker command not available in this environment"
        echo ""
        echo "On the host system, run:"
        echo "  cd $PROJECT_DIR"
        echo "  docker compose restart cloudflare-tunnel"
    fi
}

# Kill and restart standalone process
restart_standalone() {
    print_info "Restarting standalone cloudflared process"

    # Find process
    PID=$(pgrep -f cloudflared)

    if [ -n "$PID" ]; then
        print_status "Found process: $PID"
        kill "$PID"
        sleep 2
    fi

    # Start with config
    if [ -f "${PROJECT_DIR}/cloudflare/config.yml" ]; then
        print_status "Starting cloudflared with project config"
        nohup cloudflared tunnel --config "${PROJECT_DIR}/cloudflare/config.yml" run > /tmp/cloudflared.log 2>&1 &
        print_status "Started with PID: $!"
    else
        print_error "Config file not found: ${PROJECT_DIR}/cloudflare/config.yml"
    fi
}

# Test tunnel connectivity
test_tunnel() {
    print_info "Testing tunnel connectivity..."
    echo ""

    # Test public endpoint
    echo "Testing: https://api.geminiswiss1909.online/health"
    if curl -s -o /dev/null -w "%{http_code}" https://api.geminiswiss1909.online/health | grep -q "200"; then
        print_status "Public endpoint responding"
    else
        print_error "Public endpoint not responding"
    fi

    echo ""

    # Test local endpoint
    echo "Testing: http://localhost:3000/health"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
        print_status "Local MCP Gateway responding"
    else
        print_error "Local MCP Gateway not responding"
    fi
}

# Show tunnel status
show_status() {
    echo "═══════════════════════════════════════════"
    echo "  Cloudflare Tunnel Status"
    echo "═══════════════════════════════════════════"
    echo ""

    # Check systemd
    if systemctl is-active --quiet cloudflared-geminiswiss 2>/dev/null; then
        print_status "Systemd service: cloudflared-geminiswiss (active)"
        systemctl status cloudflared-geminiswiss --no-pager | head -10
    fi

    echo ""

    # Check docker
    if docker ps 2>/dev/null | grep -q cloudflare; then
        print_status "Docker container running"
        docker ps --filter "name=cloudflare" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi

    echo ""

    # Check process
    if pgrep -f cloudflared > /dev/null 2>&1; then
        print_status "Standalone process running"
        ps aux | grep cloudflared | grep -v grep
    fi

    echo ""
    test_tunnel
}

# Main menu
show_menu() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Cloudflare Tunnel Manager"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "1) Restart tunnel"
    echo "2) Show status"
    echo "3) Test connectivity"
    echo "4) View logs"
    echo "5) Exit"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) restart_tunnel ;;
        2) show_status ;;
        3) test_tunnel ;;
        4) view_logs ;;
        5) exit 0 ;;
        *) print_error "Invalid option" ; show_menu ;;
    esac
}

# Restart based on detection
restart_tunnel() {
    detect_cloudflared
    result=$?

    case $result in
        1)
            restart_systemd "cloudflared-geminiswiss.service"
            ;;
        2)
            container_name=$(docker ps --filter "name=cloudflare" --format "{{.Names}}")
            restart_docker "$container_name"
            ;;
        3)
            restart_compose
            ;;
        4)
            restart_standalone
            ;;
        0)
            print_error "Cannot restart - no cloudflared instance detected"
            echo ""
            print_info "To start cloudflared, use:"
            echo "  docker compose up -d cloudflare-tunnel"
            echo "or"
            echo "  cloudflared tunnel --config ${PROJECT_DIR}/cloudflare/config.yml run"
            ;;
    esac

    echo ""
    sleep 2
    test_tunnel
}

# View logs
view_logs() {
    echo "📋 Cloudflared Logs"
    echo "═══════════════════════════════════════════"
    echo ""

    # Systemd logs
    if systemctl list-units --full --all 2>/dev/null | grep -q "cloudflared"; then
        print_info "Systemd logs (last 50 lines):"
        sudo journalctl -u cloudflared-geminiswiss.service -n 50 --no-pager
    fi

    # Docker logs
    if docker ps 2>/dev/null | grep -q cloudflare; then
        print_info "Docker logs (last 50 lines):"
        docker logs --tail 50 $(docker ps --filter "name=cloudflare" -q)
    fi

    # Standalone logs
    if [ -f "/tmp/cloudflared.log" ]; then
        print_info "Standalone logs (last 50 lines):"
        tail -50 /tmp/cloudflared.log
    fi
}

# Parse command line arguments
case "${1:-}" in
    restart)
        restart_tunnel
        ;;
    status)
        show_status
        ;;
    test)
        test_tunnel
        ;;
    logs)
        view_logs
        ;;
    -h|--help)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  restart  - Restart cloudflared tunnel"
        echo "  status   - Show tunnel status"
        echo "  test     - Test connectivity"
        echo "  logs     - View logs"
        echo "  (none)   - Interactive menu"
        echo ""
        exit 0
        ;;
    *)
        show_menu
        ;;
esac
