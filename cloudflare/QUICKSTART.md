# Cloudflare Tunnel Quick Start

Get your services online in 5 minutes!

## Prerequisites Checklist

- [ ] Domain `geminiswiss1909.online` added to Cloudflare account
- [ ] Cloudflare account (free tier is fine)
- [ ] Services running on localhost:
  - [ ] Port 3000 (MCP Gateway)
  - [ ] Port 5678 (n8n) - optional

## Step-by-Step Setup

### 1. Install cloudflared

```bash
# Download latest release
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared

# Install
sudo mv cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared

# Verify
cloudflared version
```

### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This will open a browser window. Select your domain `geminiswiss1909.online` to authorize.

### 3. Create Tunnel

```bash
cloudflared tunnel create geminiswiss1909-tunnel
```

**Expected output:**
```
Tunnel credentials written to /home/a/.cloudflared/geminiswiss1909-tunnel.json
Created tunnel geminiswiss1909-tunnel with id <UUID>
```

### 4. Configure DNS Routes

```bash
# MCP Gateway API
cloudflared tunnel route dns geminiswiss1909-tunnel api.geminiswiss1909.online

# n8n Automation (optional)
cloudflared tunnel route dns geminiswiss1909-tunnel n8n.geminiswiss1909.online

# Root domain
cloudflared tunnel route dns geminiswiss1909-tunnel geminiswiss1909.online
```

### 5. Start Tunnel

Using the included configuration:

```bash
cd /home/user/agentEther/cloudflare

# Test run (foreground)
cloudflared tunnel --config config.yml run

# If working, set up systemd service (see below)
```

## What Just Happened?

Your local services are now accessible worldwide:

```
┌─────────────────────────────────────────────────┐
│                 Internet                        │
└────────────────────┬────────────────────────────┘
                     │
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────┐
│            Cloudflare Network                   │
│  - DDoS Protection                              │
│  - SSL/TLS Encryption                           │
│  - CDN Caching                                  │
└────────────────────┬────────────────────────────┘
                     │
                     │ Encrypted Tunnel (QUIC)
                     ▼
┌─────────────────────────────────────────────────┐
│         Your Server (localhost)                 │
│                                                 │
│  api.geminiswiss1909.online → :3000            │
│  n8n.geminiswiss1909.online → :5678            │
└─────────────────────────────────────────────────┘
```

## Test Your Services

```bash
# Test MCP Gateway
curl https://api.geminiswiss1909.online

# Test n8n (if configured)
curl https://n8n.geminiswiss1909.online

# Test in browser
xdg-open https://api.geminiswiss1909.online
```

## Production Setup (Systemd)

For production, run tunnel as a system service:

### Create systemd service

```bash
sudo nano /etc/systemd/system/cloudflared-geminiswiss.service
```

Add content:

```ini
[Unit]
Description=Cloudflare Tunnel - geminiswiss1909
After=network.target

[Service]
Type=simple
User=a
Group=a
ExecStart=/usr/local/bin/cloudflared tunnel --config /home/a/agentEther/cloudflare/config.yml run
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-geminiswiss.service
sudo systemctl start cloudflared-geminiswiss.service

# Check status
sudo systemctl status cloudflared-geminiswiss.service
```

## Verify Everything Works

```bash
# Check tunnel status
cloudflared tunnel info geminiswiss1909-tunnel

# Check DNS
dig api.geminiswiss1909.online

# Test endpoints
curl -I https://api.geminiswiss1909.online
curl -I https://n8n.geminiswiss1909.online

# View logs
sudo journalctl -u cloudflared-geminiswiss.service -f
```

## Common Commands

```bash
# Service management
sudo systemctl start cloudflared-geminiswiss.service
sudo systemctl stop cloudflared-geminiswiss.service
sudo systemctl restart cloudflared-geminiswiss.service
sudo systemctl status cloudflared-geminiswiss.service

# View live logs
sudo journalctl -u cloudflared-geminiswiss.service -f

# Tunnel info
cloudflared tunnel list
cloudflared tunnel info geminiswiss1909-tunnel

# DNS routes
cloudflared tunnel route dns list
```

## Next Steps

### 1. Secure n8n with Authentication

1. Go to: https://one.dash.cloudflare.com/
2. Navigate: **Zero Trust** → **Access** → **Applications**
3. Add application for `n8n.geminiswiss1909.online`
4. Configure access policy (email, IP, etc.)

### 2. Enable Rate Limiting

1. Dashboard: https://dash.cloudflare.com/
2. **Security** → **WAF**
3. Create rate limit rule (e.g., 100 requests / 10 minutes)

### 3. Monitor Performance

1. Visit: https://one.dash.cloudflare.com/
2. **Zero Trust** → **Access** → **Tunnels**
3. Click: `geminiswiss1909-tunnel`
4. View metrics and logs

### 4. Add More Services

Edit `config.yml`:

```yaml
ingress:
  - hostname: newservice.geminiswiss1909.online
    service: http://localhost:9000
  # ... existing rules ...
```

Route DNS:

```bash
cloudflared tunnel route dns geminiswiss1909-tunnel newservice.geminiswiss1909.online
```

Restart:

```bash
sudo systemctl restart cloudflared-geminiswiss.service
```

## Troubleshooting

### Problem: "cloudflared not found"

```bash
# Reinstall
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
sudo mv cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared
```

### Problem: "No healthy upstream" (502 errors)

```bash
# Check if services are running
netstat -tlnp | grep 3000  # Should show MCP Gateway
netstat -tlnp | grep 5678  # Should show n8n

# If using Docker
cd /home/user/agentEther
docker-compose ps
docker-compose logs mcp-gateway

# Restart services
docker-compose restart mcp-gateway
```

### Problem: DNS not resolving

```bash
# Re-add DNS routes
cloudflared tunnel route dns geminiswiss1909-tunnel api.geminiswiss1909.online

# Wait 1-2 minutes for DNS propagation
# Then test
dig api.geminiswiss1909.online
```

### Problem: Can't authenticate

```bash
# Clear and re-authenticate
rm -f ~/.cloudflared/cert.pem
cloudflared tunnel login
```

### Problem: Tunnel won't start

```bash
# Validate configuration
cloudflared tunnel ingress validate

# Check credentials
ls -l ~/.cloudflared/geminiswiss1909-tunnel.json

# Test ingress rules
cloudflared tunnel ingress rule https://api.geminiswiss1909.online
```

## Understanding the Files

```
/home/user/agentEther/cloudflare/
├── config.yml           # Tunnel configuration (routes, settings)
├── QUICKSTART.md        # This file
├── README.md            # Full documentation
├── INDEX.md             # Navigation guide
└── .gitignore           # Excludes credentials

~/.cloudflared/
├── cert.pem             # Cloudflare authentication cert
└── geminiswiss1909-tunnel.json  # Tunnel credentials (NEVER COMMIT!)
```

## Security Notes

✅ All traffic is encrypted (HTTPS + QUIC tunnel)
✅ No firewall ports need to be opened
✅ No public IP exposure
✅ DDoS protection included
✅ Free SSL/TLS certificates

**Recommendations:**
- Add Cloudflare Access for sensitive services (n8n, admin panels)
- Enable rate limiting in WAF
- Monitor logs regularly
- Keep credentials file secure (chmod 600)

## Performance

With Cloudflare Tunnel:
- **Latency**: +10-30ms (varies by location)
- **Bandwidth**: Unlimited
- **Concurrent connections**: 1000+
- **Protocol**: QUIC (modern, fast) or HTTP/2

## Cost

**COMPLETELY FREE** - Cloudflare Tunnel has no usage limits:
- ✅ Unlimited bandwidth
- ✅ Unlimited requests
- ✅ Unlimited tunnels
- ✅ DDoS protection
- ✅ SSL certificates
- ✅ Basic Zero Trust

## Success Checklist

After setup, verify:

- [ ] Tunnel service is running: `systemctl status cloudflared-geminiswiss.service`
- [ ] DNS resolves: `dig api.geminiswiss1909.online`
- [ ] HTTPS works: `curl https://api.geminiswiss1909.online`
- [ ] Browser access: Open https://api.geminiswiss1909.online
- [ ] Logs show connections: `sudo journalctl -u cloudflared-geminiswiss.service -n 50`

If all checks pass - **you're done!** Your services are now online and protected by Cloudflare.

## Integration with Docker Compose

The main `docker-compose.yml` includes a `cloudflare-tunnel` service that uses environment variable `CLOUDFLARE_TOKEN`.

For file-based credentials (recommended for production), use systemd service as shown above.

## Support

- **Full docs**: `cat README.md`
- **Index**: `cat INDEX.md`
- **Cloudflare status**: https://www.cloudflarestatus.com/
- **Cloudflare docs**: https://developers.cloudflare.com/cloudflare-one/

---

**Spectrum Protocol 2026** - Cloudflare Tunnel Quick Start
*Get online in 5 minutes, stay secure forever*
