# Cloudflare Tunnel Complete Setup - Index

**Domain**: geminiswiss1909.online
**Created**: 2026-01-10
**Status**: Ready to deploy

## File Overview

### Core Configuration Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `config.yml` | Main tunnel configuration | Edit to add/remove services or adjust settings |
| `cloudflared.service` | Systemd service template | Used automatically by setup.sh |
| `.gitignore` | Git exclusions | Prevents credentials from being committed |

### Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup.sh` | **Initial setup** | Run once: `./setup.sh` |
| `health-check.sh` | **Monitor status** | Run anytime: `./health-check.sh` |
| `maintain.sh` | **Routine maintenance** | Weekly: `./maintain.sh --full` |

### Documentation

| Document | Content | Who Should Read |
|----------|---------|-----------------|
| `QUICKSTART.md` | **Start here!** 5-min setup | Everyone (first time) |
| `README.md` | Complete reference guide | Detailed configuration needs |
| `TROUBLESHOOTING.md` | Problem solving | When things go wrong |
| `INDEX.md` | This file - navigation | Finding what you need |

## Quick Links

### First Time Setup

1. **Read**: [QUICKSTART.md](./QUICKSTART.md)
2. **Run**: `./setup.sh`
3. **Verify**: `./health-check.sh`
4. **Done!**

### Daily Operations

```bash
# Check if everything is running
./health-check.sh --quick

# View live logs
sudo journalctl -u cloudflared-geminiswiss.service -f

# Restart if needed
sudo systemctl restart cloudflared-geminiswiss.service
```

### Weekly Maintenance

```bash
# Run full maintenance
./maintain.sh --full

# Or interactive menu
./maintain.sh
```

### Troubleshooting

```bash
# Quick diagnostics
./health-check.sh

# Read troubleshooting guide
cat TROUBLESHOOTING.md | less

# Check specific issues
grep -i "error" TROUBLESHOOTING.md
```

## Service URLs

Once setup is complete, your services are available at:

- **MCP Gateway**: https://api.geminiswiss1909.online (port 3000)
- **n8n Automation**: https://n8n.geminiswiss1909.online (port 5678)
- **Root Domain**: https://geminiswiss1909.online
- **ChromaDB** (optional): https://chromadb.geminiswiss1909.online (port 8000)

## Architecture Diagram

```
                    ┌─────────────────────┐
                    │    Internet         │
                    │   (Global Users)    │
                    └──────────┬──────────┘
                               │
                               │ HTTPS
                               ▼
                    ┌─────────────────────┐
                    │  Cloudflare Network │
                    │  ─ DDoS Protection  │
                    │  ─ SSL/TLS          │
                    │  ─ CDN Caching      │
                    │  ─ WAF Rules        │
                    └──────────┬──────────┘
                               │
                               │ Encrypted Tunnel (QUIC)
                               ▼
                    ┌─────────────────────┐
                    │   cloudflared       │
                    │   (Tunnel Daemon)   │
                    └──────────┬──────────┘
                               │
                ┏━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┓
                ▼              ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │   MCP    │   │   n8n    │   │ ChromaDB │
        │ Gateway  │   │ Workflow │   │ Vector   │
        │ :3000    │   │ :5678    │   │ :8000    │
        └──────────┘   └──────────┘   └──────────┘
```

## Common Tasks

### Add a New Service

1. Edit `config.yml` - add new ingress rule:
```yaml
- hostname: newservice.geminiswiss1909.online
  service: http://localhost:9000
```

2. Route DNS:
```bash
cloudflared tunnel route dns geminiswiss1909-tunnel newservice.geminiswiss1909.online
```

3. Restart:
```bash
sudo systemctl restart cloudflared-geminiswiss.service
```

### Enable Cloudflare Access (Authentication)

1. Go to: https://one.dash.cloudflare.com/
2. Navigate: **Zero Trust** → **Access** → **Applications**
3. Add application for your subdomain
4. Configure access policy (email, IP, etc.)

### Change Tunnel Protocol

Edit `config.yml`:
```yaml
protocol: quic    # Fastest (recommended)
protocol: http2   # More compatible
protocol: auto    # Let Cloudflare decide
```

Restart service after change.

### View Metrics

```bash
# Prometheus metrics
curl http://localhost:2000/metrics

# Filtered view
curl -s http://localhost:2000/metrics | grep cloudflared_tunnel

# Real-time monitoring
watch -n 2 'curl -s http://localhost:2000/metrics | grep connections'
```

## Security Checklist

- [ ] Credentials file permissions set to 600
- [ ] Sensitive services protected with Cloudflare Access
- [ ] SSL/TLS mode set to "Full" or "Full (strict)"
- [ ] Rate limiting configured in Cloudflare WAF
- [ ] Regular backups scheduled (`./maintain.sh --backup`)
- [ ] Security audit run monthly (`./maintain.sh --security`)
- [ ] Only necessary services exposed

## Monitoring Checklist

- [ ] Daily: Quick health check (`./health-check.sh --quick`)
- [ ] Weekly: Full maintenance (`./maintain.sh --full`)
- [ ] Monthly: Review logs and metrics
- [ ] Quarterly: Security audit and optimization review

## Backup Strategy

**Automatic backups** (via maintain.sh):
- Configuration files
- Credentials
- Systemd service
- Last 10 backups kept

**Manual backup**:
```bash
./maintain.sh --backup
```

**Restore from backup**:
```bash
cp ~/tunnel-backups/backup_YYYYMMDD_HHMMSS/config.yml .
sudo systemctl restart cloudflared-geminiswiss.service
```

## Performance Tuning

### Low Latency
```yaml
protocol: quic
originRequest:
  connectTimeout: 10s
  keepAliveTimeout: 30s
```

### High Throughput
```yaml
protocol: http2
originRequest:
  keepAliveConnections: 200
  tcpKeepAlive: 30s
```

### Long-Running Requests
```yaml
originRequest:
  connectTimeout: 60s
  keepAliveTimeout: 120s
  noHappyEyeballs: false
```

## Integration Examples

### n8n Webhook Example

```javascript
// n8n workflow receives webhook at:
https://n8n.geminiswiss1909.online/webhook/your-path

// No special configuration needed - works out of the box
```

### Python API Client

```python
import requests

# Call your MCP Gateway
response = requests.post(
    "https://api.geminiswiss1909.online/endpoint",
    json={"key": "value"}
)
```

### curl Examples

```bash
# GET request
curl https://api.geminiswiss1909.online/status

# POST request
curl -X POST https://api.geminiswiss1909.online/api \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'

# With authentication
curl -H "Authorization: Bearer TOKEN" \
  https://api.geminiswiss1909.online/secure
```

## Cost Analysis

**Cloudflare Tunnel: FREE**
- ✅ Unlimited bandwidth
- ✅ Unlimited requests
- ✅ Unlimited tunnels
- ✅ DDoS protection
- ✅ SSL certificates
- ✅ Basic Zero Trust

**Optional Paid Features** (not required):
- Advanced Zero Trust policies
- Browser isolation
- Data Loss Prevention
- Premium support

## Disaster Recovery

### Complete System Failure

```bash
# 1. Stop broken service
sudo systemctl stop cloudflared-geminiswiss.service

# 2. Delete tunnel
cloudflared tunnel delete geminiswiss1909-tunnel

# 3. Remove credentials
rm -f ~/.cloudflared/geminiswiss1909-tunnel.json

# 4. Re-run setup
./setup.sh
```

### Restore from Backup

```bash
# 1. List available backups
ls -lt ~/tunnel-backups/

# 2. Restore specific backup
cp ~/tunnel-backups/backup_YYYYMMDD_HHMMSS/config.yml .
cp ~/tunnel-backups/backup_YYYYMMDD_HHMMSS/credentials.json \
   ~/.cloudflared/geminiswiss1909-tunnel.json

# 3. Restart
sudo systemctl restart cloudflared-geminiswiss.service
```

## Support Resources

### Internal Resources
- Quick Start: `cat QUICKSTART.md`
- Full Docs: `cat README.md`
- Troubleshooting: `cat TROUBLESHOOTING.md`
- Health Check: `./health-check.sh`

### Cloudflare Resources
- Documentation: https://developers.cloudflare.com/cloudflare-one/
- Community Forum: https://community.cloudflare.com/
- Status Page: https://www.cloudflarestatus.com/
- Dashboard: https://dash.cloudflare.com/

### Command Reference
```bash
# Service management
sudo systemctl {start|stop|restart|status} cloudflared-geminiswiss.service

# Tunnel commands
cloudflared tunnel list
cloudflared tunnel info geminiswiss1909-tunnel
cloudflared tunnel route dns list

# Log viewing
sudo journalctl -u cloudflared-geminiswiss.service -f
sudo journalctl -u cloudflared-geminiswiss.service -n 100

# Configuration validation
cloudflared tunnel ingress validate
cloudflared tunnel validate
```

## File Permissions

Correct permissions for security:

```bash
# Configuration
chmod 644 config.yml

# Scripts
chmod 755 *.sh

# Credentials (critical!)
chmod 600 ~/.cloudflared/*.json
chmod 600 ~/.cloudflared/cert.pem

# Systemd service
chmod 644 /etc/systemd/system/cloudflared-geminiswiss.service
```

## Environment Variables

The tunnel uses these environment variables (optional):

```bash
# Set in systemd service file
TUNNEL_ORIGIN_CERT=/home/a/.cloudflared/cert.pem
TUNNEL_LOGLEVEL=info  # debug, info, warn, error

# For custom paths
TUNNEL_CONFIG=/path/to/config.yml
TUNNEL_CREDENTIALS=/path/to/credentials.json
```

## Testing Procedures

### Pre-Deployment Tests

```bash
# 1. Validate configuration
cloudflared tunnel ingress validate

# 2. Test local services
curl http://localhost:3000  # MCP Gateway
curl http://localhost:5678  # n8n

# 3. Check DNS
dig api.geminiswiss1909.online
```

### Post-Deployment Tests

```bash
# 1. Service status
systemctl status cloudflared-geminiswiss.service

# 2. Endpoint availability
curl -I https://api.geminiswiss1909.online
curl -I https://n8n.geminiswiss1909.online

# 3. Full health check
./health-check.sh
```

### Load Testing (Optional)

```bash
# Using Apache Bench
ab -n 1000 -c 10 https://api.geminiswiss1909.online/

# Using wrk
wrk -t4 -c100 -d30s https://api.geminiswiss1909.online/
```

## Changelog

### 2026-01-10 - Initial Setup
- Created complete Cloudflare Tunnel configuration
- Added setup, health-check, and maintenance scripts
- Comprehensive documentation suite
- Security best practices implemented
- Monitoring and alerting configured

## Next Steps After Setup

1. ✅ Complete initial setup with `./setup.sh`
2. ✅ Verify with `./health-check.sh`
3. ⏳ Configure Cloudflare Access for sensitive services
4. ⏳ Set up rate limiting in WAF
5. ⏳ Enable monitoring and alerts
6. ⏳ Schedule weekly maintenance: `crontab -e`
   ```
   0 2 * * 0 /home/a/agentEther/cloudflare/maintain.sh --full
   ```
7. ⏳ Test disaster recovery procedure
8. ⏳ Document custom configurations

---

**Need Help?**

1. Check [QUICKSTART.md](./QUICKSTART.md) for basic setup
2. Read [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for specific issues
3. Run `./health-check.sh` for diagnostics
4. Review [README.md](./README.md) for detailed configuration

**Status**: Ready for production deployment! 🚀
