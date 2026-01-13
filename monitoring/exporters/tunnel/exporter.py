#!/usr/bin/env python3
"""
Cloudflare Tunnel Prometheus Exporter
Exports metrics about Cloudflare Tunnel status
"""

import os
import time
import requests
from prometheus_client import start_http_server, Gauge, Counter, Info
from typing import Optional

# Configuration
CLOUDFLARE_ACCOUNT_ID = os.getenv("CLOUDFLARE_ACCOUNT_ID", "")
CLOUDFLARE_TUNNEL_ID = os.getenv("CLOUDFLARE_TUNNEL_ID", "")
CLOUDFLARE_API_TOKEN = os.getenv("CLOUDFLARE_API_TOKEN", "")
EXPORTER_PORT = int(os.getenv("EXPORTER_PORT", "9300"))
SCRAPE_INTERVAL = int(os.getenv("SCRAPE_INTERVAL", "60"))

# Local tunnel health check
LOCAL_TUNNEL_URL = os.getenv("LOCAL_TUNNEL_URL", "http://localhost:3000/health")
PUBLIC_TUNNEL_URL = os.getenv("PUBLIC_TUNNEL_URL", "https://api.geminiswiss1909.online/health")

# Metrics
tunnel_status = Gauge('cloudflare_tunnel_status', 'Tunnel status (1=up, 0=down)', ['tunnel_id'])
tunnel_connections = Gauge('cloudflare_tunnel_connections', 'Number of active connections', ['tunnel_id'])
tunnel_response_time = Gauge('cloudflare_tunnel_response_time_seconds', 'Response time in seconds', ['endpoint'])
tunnel_errors = Counter('cloudflare_tunnel_errors_total', 'Total number of tunnel errors', ['type'])
tunnel_info = Info('cloudflare_tunnel', 'Information about the tunnel')

# MCP Gateway metrics
mcp_gateway_up = Gauge('mcp_gateway_up', 'MCP Gateway status (1=up, 0=down)', ['endpoint'])


def check_tunnel_api() -> Optional[dict]:
    """Check tunnel status via Cloudflare API"""
    if not all([CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_TUNNEL_ID, CLOUDFLARE_API_TOKEN]):
        return None

    try:
        url = f"https://api.cloudflare.com/client/v4/accounts/{CLOUDFLARE_ACCOUNT_ID}/cfd_tunnel/{CLOUDFLARE_TUNNEL_ID}"
        headers = {
            "Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}",
            "Content-Type": "application/json"
        }

        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()

        data = response.json()
        if data.get("success"):
            return data.get("result", {})

        return None

    except Exception as e:
        tunnel_errors.labels(type="api_error").inc()
        print(f"Error checking Cloudflare API: {e}")
        return None


def check_endpoint(url: str, label: str) -> bool:
    """Check if an endpoint is reachable"""
    try:
        start = time.time()
        response = requests.get(url, timeout=5)
        duration = time.time() - start

        tunnel_response_time.labels(endpoint=label).set(duration)

        if response.status_code == 200:
            mcp_gateway_up.labels(endpoint=label).set(1)
            return True
        else:
            mcp_gateway_up.labels(endpoint=label).set(0)
            tunnel_errors.labels(type="http_error").inc()
            return False

    except requests.exceptions.Timeout:
        tunnel_response_time.labels(endpoint=label).set(5)
        mcp_gateway_up.labels(endpoint=label).set(0)
        tunnel_errors.labels(type="timeout").inc()
        return False

    except Exception as e:
        mcp_gateway_up.labels(endpoint=label).set(0)
        tunnel_errors.labels(type="connection_error").inc()
        print(f"Error checking {url}: {e}")
        return False


def collect_metrics():
    """Collect all tunnel metrics"""
    # Check tunnel via API
    tunnel_data = check_tunnel_api()

    if tunnel_data:
        # Tunnel is configured
        status = 1 if tunnel_data.get("status") == "active" else 0
        tunnel_status.labels(tunnel_id=CLOUDFLARE_TUNNEL_ID).set(status)

        # Get connections count if available
        connections = tunnel_data.get("connections", [])
        tunnel_connections.labels(tunnel_id=CLOUDFLARE_TUNNEL_ID).set(len(connections))

        # Set tunnel info
        tunnel_info.info({
            'tunnel_id': CLOUDFLARE_TUNNEL_ID,
            'name': tunnel_data.get('name', 'unknown'),
            'created_at': tunnel_data.get('created_at', 'unknown')
        })
    else:
        # Fallback: Check endpoints directly
        local_up = check_endpoint(LOCAL_TUNNEL_URL, "local")
        public_up = check_endpoint(PUBLIC_TUNNEL_URL, "public")

        # If public endpoint is up, tunnel is working
        if public_up:
            tunnel_status.labels(tunnel_id=CLOUDFLARE_TUNNEL_ID or "unknown").set(1)
        else:
            tunnel_status.labels(tunnel_id=CLOUDFLARE_TUNNEL_ID or "unknown").set(0)


def main():
    """Main exporter loop"""
    print(f"Starting Cloudflare Tunnel Exporter on port {EXPORTER_PORT}")
    print(f"Scrape interval: {SCRAPE_INTERVAL}s")

    # Start HTTP server for Prometheus scraping
    start_http_server(EXPORTER_PORT)

    # Main loop
    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Error in main loop: {e}")
            tunnel_errors.labels(type="exporter_error").inc()

        time.sleep(SCRAPE_INTERVAL)


if __name__ == "__main__":
    main()
