# Cloudflare Tunnel for Spectrum Protocol 2026

## Overview

This directory contains the Cloudflare Tunnel configuration for the agentEther MCP Gateway, providing secure, encrypted access to your services without opening firewall ports.

## Services Exposed

| Service | URL | Port | Status |
|---------|-----|------|--------|
| MCP Gateway | https://api.geminiswiss1909.online | 3000 | ✅ Active |
| n8n Automation | https://n8n.geminiswiss1909.online | 5678 | ⏳ Optional |
| ChromaDB | https://chromadb.geminiswiss1909.online | 8000 | 💤 Disabled |
| Root Domain | https://geminiswiss1909.online | 3000 | ✅ Active |

## Quick Start

### Prerequisites

```bash
# Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
sudo mv cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared
```

### Setup Steps

1. **Authenticate** (one-time)
```bash
cloudflared tunnel login
```

2. **Create Tunnel** (if not exists)
```bash
cloudflared tunnel create geminiswiss1909-tunnel
```

3. **Configure DNS** (for each subdomain)
```bash
cloudflared tunnel route dns geminiswiss1909-tunnel api.geminiswiss1909.online
cloudflared tunnel route dns geminiswiss1909-tunnel n8n.geminiswiss1909.online
cloudflared tunnel route dns geminiswiss1909-tunnel geminiswiss1909.online
```

4. **Copy Credentials**
```bash
# The setup script creates credentials at:
# ~/.cloudflared/geminiswiss1909-tunnel.json

# Verify it exists
ls -l ~/.cloudflared/geminiswiss1909-tunnel.json
```

5. **Start Tunnel**
```bash
# Test run (foreground)
cloudflared tunnel --config config.yml run

# Or use Docker (recommended)
# See "Docker Integration" section below
```

## Integration with Docker Compose

### Option 1: Use Cloudflare Tunnel Service (Recommended)

The main `docker-compose.yml` already includes the `cloudflare-tunnel` service:

```bash
# From project root
cd /home/user/agentEther

# Copy credentials to accessible location
cp ~/.cloudflared/geminiswiss1909-tunnel.json ./cloudflare/

# Start with tunnel
docker-compose up -d
```

**Note:** The tunnel service in `docker-compose.yml` uses environment variable `CLOUDFLARE_TOKEN`. For file-based credentials, modify the docker-compose service or use systemd.

### Option 2: Systemd Service (Production)

For production deployments, use systemd:

```bash
# Create systemd service
sudo nano /etc/systemd/system/cloudflared-geminiswiss.service

# Add content (see cloudflared.service template)

# Enable and start
sudo systemctl enable cloudflared-geminiswiss.service
sudo systemctl start cloudflared-geminiswiss.service

# Check status
sudo systemctl status cloudflared-geminiswiss.service
```

## Configuration Files

### config.yml

Main tunnel configuration defining:
- Ingress rules (hostname → service mapping)
- Origin request settings (timeouts, headers)
- Protocol (QUIC recommended)
- Logging and metrics

**Edit to:**
- Add new services
- Change timeouts
- Modify protocol
- Enable/disable metrics

### Ingress Rule Order

**IMPORTANT:** Rules are evaluated top-to-bottom. More specific rules must come first!

```yaml
# ✅ CORRECT - specific before general
- hostname: api.geminiswiss1909.online
  service: http://localhost:3000
- hostname: "*.geminiswiss1909.online"
  service: http://localhost:3000

# ❌ WRONG - wildcard catches everything
- hostname: "*.geminiswiss1909.online"
  service: http://localhost:3000
- hostname: api.geminiswiss1909.online
  service: http://localhost:3000  # Never reached!
```

## Adding New Services

### 1. Add Service to Docker Compose

Edit `../docker-compose.yml`:

```yaml
services:
  myservice:
    image: my/image
    ports:
      - "9000:9000"
    networks:
      - multiplexer-network
```

### 2. Add Ingress Rule

Edit `cloudflare/config.yml`:

```yaml
ingress:
  - hostname: myservice.geminiswiss1909.online
    service: http://localhost:9000
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
  # ... existing rules ...
```

### 3. Route DNS

```bash
cloudflared tunnel route dns geminiswiss1909-tunnel myservice.geminiswiss1909.online
```

### 4. Restart Tunnel

```bash
# Docker
docker-compose restart cloudflare-tunnel

# Systemd
sudo systemctl restart cloudflared-geminiswiss.service
```

### 5. Test

```bash
curl -I https://myservice.geminiswiss1909.online
```

## Security Configuration

### Enable Cloudflare Access

Protect sensitive services with authentication:

1. **Go to Cloudflare Dashboard**
   - https://one.dash.cloudflare.com/

2. **Navigate to Zero Trust**
   - Access → Applications → Add an application

3. **Configure Application**
   - Self-hosted
   - Domain: `n8n.geminiswiss1909.online`
   - Policy: Email, IP, etc.

4. **Save**
   - Changes apply immediately
   - No tunnel restart needed

### WAF Rules

Add rate limiting and security rules:

1. **Dashboard:** https://dash.cloudflare.com/
2. **Security** → **WAF**
3. **Create Rule:**
   - Rate limit: 100 requests / 10 minutes
   - Block suspicious user agents
   - Geo-blocking (if needed)

### SSL/TLS Settings

Recommended configuration:

```
SSL/TLS encryption mode: Full (strict)
TLS version: 1.2+
HSTS: Enabled (max-age: 31536000)
```

## Monitoring

### Prometheus Metrics

Tunnel exposes Prometheus metrics at `localhost:2000`:

```bash
# View all metrics
curl http://localhost:2000/metrics

# Specific metrics
curl -s http://localhost:2000/metrics | grep cloudflared_tunnel_
```

**Key Metrics:**
- `cloudflared_tunnel_total_requests` - Total requests
- `cloudflared_tunnel_requests_per_tunnel` - Per-tunnel requests
- `cloudflared_tunnel_response_time_seconds` - Response times
- `cloudflared_tunnel_connections` - Active connections

### Grafana Dashboard

Use metrics with Grafana:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cloudflare-tunnel'
    static_configs:
      - targets: ['localhost:2000']
```

### Logs

```bash
# Systemd
sudo journalctl -u cloudflared-geminiswiss.service -f

# Docker
docker-compose logs -f cloudflare-tunnel

# Last 100 lines
sudo journalctl -u cloudflared-geminiswiss.service -n 100
```

## Troubleshooting

### Tunnel Won't Start

```bash
# Check credentials
ls -l ~/.cloudflared/geminiswiss1909-tunnel.json
cat ~/.cloudflared/geminiswiss1909-tunnel.json | jq .

# Validate config
cloudflared tunnel ingress validate

# Test ingress rules
cloudflared tunnel ingress rule https://api.geminiswiss1909.online
```

### DNS Not Resolving

```bash
# Check DNS routing
cloudflared tunnel route dns list

# Test resolution
dig api.geminiswiss1909.online
nslookup api.geminiswiss1909.online
```

### Service Unreachable

```bash
# Test local service
curl http://localhost:3000

# Check Docker network
docker network inspect multiplexer-network

# Verify tunnel is running
ps aux | grep cloudflared
```

### 502 Bad Gateway

Possible causes:
1. Service not running (`docker-compose ps`)
2. Wrong port in config.yml
3. Service not accessible from tunnel
4. Firewall blocking localhost connections

**Fix:**
```bash
# Restart services
docker-compose restart mcp-gateway

# Check service logs
docker-compose logs mcp-gateway

# Verify service is listening
netstat -tlnp | grep 3000
```

## Performance Optimization

### Protocol Selection

```yaml
# Fastest (recommended)
protocol: quic

# Most compatible
protocol: http2

# Auto-select
protocol: auto
```

### Connection Tuning

For long-running connections (e.g., WebSockets):

```yaml
originRequest:
  connectTimeout: 60s
  keepAliveTimeout: 120s
  keepAliveConnections: 100
```

For high-throughput:

```yaml
originRequest:
  connectTimeout: 10s
  keepAliveTimeout: 30s
  keepAliveConnections: 200
  tcpKeepAlive: 30s
```

## Backup and Restore

### Backup

```bash
# Manual backup
mkdir -p ~/tunnel-backups
cp config.yml ~/tunnel-backups/config.yml.$(date +%Y%m%d)
cp ~/.cloudflared/geminiswiss1909-tunnel.json ~/tunnel-backups/
```

### Restore

```bash
# Restore configuration
cp ~/tunnel-backups/config.yml.YYYYMMDD config.yml

# Restart tunnel
sudo systemctl restart cloudflared-geminiswiss.service
```

## Environment-Specific Configuration

### SWISSAI Environment

The tunnel configuration is environment-agnostic. It works with both SWISSAI and Anthropic Cloud because it tunnels to `localhost:3000` regardless of environment.

**Key Point:** The MCP Gateway (port 3000) is the same in both environments, only the internal configuration differs (see `../environments/`).

### Testing Different Environments

```bash
# Switch to SWISSAI
cd ..
./switch-env.sh swissai
docker-compose up -d

# Tunnel works with SWISSAI environment
curl https://api.geminiswiss1909.online

# Switch to Anthropic Cloud
./switch-env.sh anthropic
docker-compose up -d

# Tunnel still works (same port)
curl https://api.geminiswiss1909.online
```

## Advanced Configuration

### Custom Headers

```yaml
originRequest:
  httpHostHeader: api.geminiswiss1909.online
  originServerName: custom-name
  caPool: /path/to/ca.pem
```

### Proxy Settings

```yaml
originRequest:
  proxyAddress: proxy.example.com
  proxyPort: 8080
  proxyType: http  # or socks5
```

### Multiple Tunnels

You can run multiple tunnels for redundancy:

```bash
# Create second tunnel
cloudflared tunnel create geminiswiss1909-tunnel-backup

# Route same domains to both
cloudflared tunnel route dns geminiswiss1909-tunnel-backup api.geminiswiss1909.online

# Start both tunnels (different configs)
cloudflared tunnel --config config.yml run &
cloudflared tunnel --config config-backup.yml run &
```

## Integration with n8n

If you're running n8n automation:

### n8n Configuration

```bash
# n8n webhook URL
https://n8n.geminiswiss1909.online/webhook/your-webhook-id

# n8n editor
https://n8n.geminiswiss1909.online
```

### n8n Environment Variables

```env
# In n8n container
WEBHOOK_URL=https://n8n.geminiswiss1909.online/
N8N_HOST=n8n.geminiswiss1909.online
N8N_PROTOCOL=https
N8N_PORT=443
```

## Cost

**Cloudflare Tunnel is FREE:**
- ✅ Unlimited bandwidth
- ✅ Unlimited requests
- ✅ DDoS protection included
- ✅ SSL certificates included
- ✅ No egress charges

**No hidden costs** - completely free tier includes everything needed for production use.

## Support

### Official Resources
- Docs: https://developers.cloudflare.com/cloudflare-one/
- Forum: https://community.cloudflare.com/
- Status: https://www.cloudflarestatus.com/

### Project Resources
- Main README: `../README.md`
- Environment Setup: `../ENVIRONMENTS.md`
- Google Drive Sync: `../GDRIVE-SYNC.md`

### Getting Help

1. Check `INDEX.md` for navigation
2. Run health checks: `./health-check.sh`
3. Review logs: `sudo journalctl -u cloudflared-geminiswiss.service -n 100`
4. Validate config: `cloudflared tunnel ingress validate`

---

**Spectrum Protocol 2026** - Cloudflare Tunnel Integration
*Secure, encrypted, and free public access to your services*
