#!/bin/bash
# Spectrum Protocol 2026 - Environment Switcher
# Switches between SWISSAI and Anthropic Cloud environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENTS_DIR="${SCRIPT_DIR}/environments"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Spectrum Protocol 2026 - Environment Switch  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Available environments:"
    echo "  swissai     - Switch to SWISSAI/geminiswiss environment"
    echo "  anthropic   - Switch to Anthropic Cloud environment"
    echo ""
    echo "Example:"
    echo "  $0 swissai"
    echo ""
}

check_environment_exists() {
    local env=$1
    if [ ! -d "${ENVIRONMENTS_DIR}/${env}" ]; then
        print_error "Environment '${env}' not found!"
        echo ""
        show_usage
        exit 1
    fi
}

backup_current_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${SCRIPT_DIR}/.env.backups"

    mkdir -p "${backup_dir}"

    if [ -f "${SCRIPT_DIR}/.env" ]; then
        cp "${SCRIPT_DIR}/.env" "${backup_dir}/.env.${timestamp}"
        print_success "Backed up current .env to ${backup_dir}/.env.${timestamp}"
    fi

    if [ -f "${SCRIPT_DIR}/docker-compose.override.yml" ]; then
        cp "${SCRIPT_DIR}/docker-compose.override.yml" "${backup_dir}/docker-compose.override.${timestamp}.yml"
        print_success "Backed up current docker-compose.override.yml"
    fi
}

switch_environment() {
    local env=$1
    local env_dir="${ENVIRONMENTS_DIR}/${env}"

    print_header
    print_info "Switching to ${env} environment..."
    echo ""

    # Check if environment exists
    check_environment_exists "${env}"

    # Backup current configuration
    print_info "Creating backup of current configuration..."
    backup_current_config
    echo ""

    # Copy environment-specific files
    print_info "Applying ${env} configuration..."

    # Copy .env template if no .env exists
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${env_dir}/.env.template" ]; then
            cp "${env_dir}/.env.template" "${SCRIPT_DIR}/.env"
            print_warning ".env created from template - YOU MUST EDIT IT WITH YOUR CREDENTIALS!"
        fi
    else
        print_info ".env already exists - keeping current file"
        print_warning "Check environments/${env}/.env.template for required variables"
    fi

    # Copy docker-compose override
    if [ -f "${env_dir}/docker-compose.override.yml" ]; then
        cp "${env_dir}/docker-compose.override.yml" "${SCRIPT_DIR}/docker-compose.override.yml"
        print_success "Applied docker-compose.override.yml for ${env}"
    fi

    echo ""
    print_success "Environment switched to: ${env}"
    echo ""

    # Show next steps
    print_info "Next steps:"
    echo "  1. Edit .env file with your ${env} credentials"
    echo "  2. Review docker-compose.override.yml settings"
    echo "  3. Run: docker-compose config (to verify configuration)"
    echo "  4. Run: docker-compose up -d (to start services)"
    echo ""

    # Show current environment indicator
    print_info "Current environment: ${env}"
    echo ""
}

# Main script
if [ $# -eq 0 ]; then
    print_header
    print_error "No environment specified!"
    echo ""
    show_usage
    exit 1
fi

ENVIRONMENT=$1

case $ENVIRONMENT in
    swissai|anthropic)
        switch_environment "$ENVIRONMENT"
        ;;
    --help|-h)
        print_header
        show_usage
        ;;
    *)
        print_header
        print_error "Unknown environment: $ENVIRONMENT"
        echo ""
        show_usage
        exit 1
        ;;
esac
