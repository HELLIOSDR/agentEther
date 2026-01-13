# Prometheus + Grafana Monitoring Stack

Complete monitoring solution for Spectrum Protocol 2026 with Prometheus, Grafana, and custom exporters.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Grafana (3001)                        │
│              Dashboards & Visualization                 │
└────────────────┬────────────────────────────────────────┘
                 │ queries
                 ▼
┌─────────────────────────────────────────────────────────┐
│                  Prometheus (9090)                       │
│              Metrics Storage & Queries                   │
└──┬───────┬──────┬──────┬──────┬──────┬──────┬──────────┘
   │       │      │      │      │      │      │
   │       │      │      │      │      │      └─► AlertManager (9093)
   │       │      │      │      │      │
   │       │      │      │      │      └────────► Custom Exporters
   │       │      │      │      │                 - Tunnel (9300)
   │       │      │      │      │
   │       │      │      │      └───────────────► Blackbox (9115)
   │       │      │      │                        HTTP/TCP probes
   │       │      │      │
   │       │      │      └──────────────────────► cAdvisor (8080)
   │       │      │                               Container metrics
   │       │      │
   │       │      └─────────────────────────────► Node Exporter (9100)
   │       │                                      System metrics
   │       │
   │       └────────────────────────────────────► MCP Gateway (3000)
   │                                              Application metrics
   │
   └────────────────────────────────────────────► ChromaDB (8001)
                                                  Database metrics
```

## Components

### Core Monitoring
- **Prometheus** - Time-series database and metrics aggregation
- **Grafana** - Visualization and dashboards
- **AlertManager** - Alert routing and notification

### System Exporters
- **Node Exporter** - Host system metrics (CPU, memory, disk, network)
- **cAdvisor** - Container metrics (Docker)
- **Blackbox Exporter** - HTTP/TCP endpoint probing

### Custom Exporters
- **Tunnel Exporter** - Cloudflare Tunnel status and health
- **MCP Gateway** - Application-level metrics (if instrumented)

## Quick Start

### 1. Configuration

Create `.env` file:

```bash
# Grafana Admin
ADMIN_USER=admin
ADMIN_PASSWORD=your_secure_password_here

# Cloudflare (optional - for tunnel monitoring)
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_TUNNEL_ID=your_tunnel_id
CLOUDFLARE_API_TOKEN=your_api_token

# AlertManager (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### 2. Start Monitoring Stack

```bash
cd monitoring
docker-compose up -d
```

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3001 | admin / (from .env) |
| Prometheus | http://localhost:9090 | none |
| AlertManager | http://localhost:9093 | none |
| cAdvisor | http://localhost:8080 | none |

### 4. Verify

```bash
# Check all services are running
docker-compose ps

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check AlertManager status
curl http://localhost:9093/api/v1/status
```

## Metrics Collected

### System Metrics (Node Exporter)

- CPU usage, load average
- Memory usage (used, available, cached)
- Disk usage and I/O
- Network traffic and errors
- System uptime

### Container Metrics (cAdvisor)

- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage
- Container restart count

### MCP Gateway Metrics

- HTTP request rate and duration
- Error rate by status code
- Active connections
- Request/response sizes
- Custom business metrics

### Cloudflare Tunnel Metrics

- Tunnel status (up/down)
- Active connections count
- Response time to endpoints
- Error counts by type

## Alerts

### Critical Alerts

- **MCPGatewayDown** - MCP Gateway unreachable for 2+ minutes
- **CloudflareTunnelDown** - Tunnel down for 2+ minutes
- **DiskSpaceLow** - Less than 10% disk space
- **HighMemoryUsage** - Memory usage above 90%

### Warning Alerts

- **MCPGatewayHighErrorRate** - Error rate above 5%
- **MCPGatewayHighLatency** - 95th percentile > 2s
- **HighContainerCPU** - Container CPU > 80%
- **HighContainerMemory** - Container memory > 90%
- **HighSystemLoad** - Load average > 1.5

See `prometheus/rules/alerts.yml` for full alert definitions.

## Grafana Dashboards

### Pre-configured Dashboards

1. **Spectrum Protocol Overview** - High-level system health
2. **Docker Containers** - Container metrics and health
3. **Node Metrics** - System-level metrics
4. **MCP Gateway** - Application-specific metrics
5. **Cloudflare Tunnel** - Tunnel status and performance

### Import Community Dashboards

Recommended dashboard IDs from https://grafana.com/grafana/dashboards/:

- **1860** - Node Exporter Full
- **893** - Docker and System Monitoring
- **11600** - Docker Host & Container Overview
- **3662** - Prometheus 2.0 Overview

Import via Grafana UI: Configuration → Dashboards → Import

## Custom Exporters

### Cloudflare Tunnel Exporter

Located in `exporters/tunnel/`, this custom exporter provides:

- Tunnel status via Cloudflare API
- Health checks for local and public endpoints
- Response time measurements
- Connection count

**Metrics:**
- `cloudflare_tunnel_status` - Tunnel up/down status
- `cloudflare_tunnel_connections` - Active connections
- `cloudflare_tunnel_response_time_seconds` - Endpoint response time
- `cloudflare_tunnel_errors_total` - Error counter
- `mcp_gateway_up` - Gateway availability

**Configuration:**

Set in `monitoring/.env`:
```bash
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_TUNNEL_ID=your_tunnel_id
CLOUDFLARE_API_TOKEN=your_api_token
```

## AlertManager Configuration

### Webhook Integration

AlertManager can send alerts to:

- Coordination system (webhook)
- Slack
- Email
- PagerDuty
- Opsgenie
- And more...

### Coordination Integration

Alerts are automatically sent to the coordination webhook which triggers:

1. Desktop notifications via `coordination/notify.sh`
2. Messages in coordination system
3. Logs to `logs/notifications.log`

Edit `alertmanager/config.yml` to customize.

## Production Recommendations

### 1. Security

```bash
# Change default Grafana password immediately
# Set in .env:
ADMIN_PASSWORD=strong_random_password_here

# Use HTTPS for Grafana (behind Cloudflare Tunnel)
GF_SERVER_ROOT_URL=https://grafana.geminiswiss1909.online
```

### 2. Data Retention

Edit `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Add storage retention
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
```

### 3. Resource Limits

Add to `docker-compose.yml`:

```yaml
services:
  prometheus:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### 4. Backups

```bash
# Backup Prometheus data
docker run --rm -v monitoring_prometheus_data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/prometheus-$(date +%Y%m%d).tar.gz /data

# Backup Grafana data
docker run --rm -v monitoring_grafana_data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/grafana-$(date +%Y%m%d).tar.gz /data
```

### 5. High Availability

For production, consider:

- Prometheus federation or Thanos for long-term storage
- Multiple Prometheus instances with load balancing
- Grafana behind load balancer
- AlertManager clustering

## Troubleshooting

### Prometheus Not Scraping

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Check Prometheus logs
docker-compose logs prometheus

# Verify network connectivity
docker exec prometheus wget -O- http://nodeexporter:9100/metrics
```

### Grafana Can't Connect to Prometheus

```bash
# Check datasource configuration
docker exec grafana cat /etc/grafana/provisioning/datasources/datasource.yml

# Test connection from Grafana container
docker exec grafana wget -O- http://prometheus:9090/api/v1/status/config
```

### High Memory Usage

```bash
# Check Prometheus memory usage
docker stats prometheus

# Reduce scrape frequency in prometheus.yml
# Reduce retention time
# Reduce number of time series (fewer labels)
```

### Alerts Not Firing

```bash
# Check AlertManager status
curl http://localhost:9093/api/v1/status

# Check Prometheus rules
curl http://localhost:9090/api/v1/rules

# Check alert state
curl http://localhost:9090/api/v1/alerts

# View AlertManager logs
docker-compose logs alertmanager
```

## Integration with Spectrum Protocol

### MCP Gateway Metrics

To export metrics from MCP Gateway, add Prometheus client:

```javascript
// In MCP Gateway code
const promClient = require('prom-client');
const register = new promClient.Registry();

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});
```

### Coordination Metrics

Export coordination metrics:

```bash
# In coordination scripts, export metrics
cat > /var/lib/node_exporter/textfile_collector/coordination.prom <<EOF
# HELP coordination_sync_failures_total Total sync failures
# TYPE coordination_sync_failures_total counter
coordination_sync_failures_total 0

# HELP coordination_unread_messages Unread messages count
# TYPE coordination_unread_messages gauge
coordination_unread_messages 5
EOF
```

## Maintenance

### Update Images

```bash
cd monitoring
docker-compose pull
docker-compose up -d
```

### Clean Up Old Data

```bash
# Remove old Prometheus data (keeps last 7 days)
docker exec prometheus promtool tsdb delete-blocks -r /prometheus --max-time=$(date -d '7 days ago' +%s)000
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f prometheus
docker-compose logs -f grafana
docker-compose logs -f tunnel-exporter
```

## Advanced Features

### Prometheus Federation

For multi-environment setup:

```yaml
# In monitoring prometheus.yml
scrape_configs:
  - job_name: 'federate-swissai'
    scrape_interval: 60s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="prometheus"}'
        - '{__name__=~"^job:.*"}'
    static_configs:
      - targets:
          - 'prometheus-swissai:9090'
```

### Recording Rules

For frequently used queries:

```yaml
# In prometheus/rules/recording.yml
groups:
  - name: spectrum_recording
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: rate(http_requests_total[5m])

      - record: job:http_errors:rate5m
        expr: rate(http_requests_total{status=~"5.."}[5m])
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor](https://github.com/google/cadvisor)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Dockprom (Base Project)](https://github.com/stefanprodan/dockprom)

---

**Spectrum Protocol 2026** - Production Monitoring Stack
*Built for reliability, observability, and performance*
