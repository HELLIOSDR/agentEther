# Spectrum Protocol 2026 - Stabilized Kernel Architecture

## Overview

The Spectrum Protocol 2026 is a stabilized kernel architecture for the agentEther project, featuring an MCP (Model Context Protocol) gateway with Cloudflare tunnel integration.

## Architecture

```
┌─────────────────────────────────────────┐
│     Cloudflare Tunnel (cloudflared)     │
│         Port: Dynamic                    │
└──────────────┬──────────────────────────┘
               │ depends_on (healthy)
               ▼
┌─────────────────────────────────────────┐
│         MCP Gateway Service             │
│    Ports: 3000 (HTTP), 3001 (Socket)    │
│                                         │
│  • Model Context Protocol               │
│  • Socket.io Support                    │
│  • Security Tools Integration           │
│  • Health Monitoring                    │
└─────────────────────────────────────────┘
```

## Recent Stability Fixes

This release addresses three critical kernel stability issues:

### 1. Profile Blocking Tunnel ✅
**Problem:** Cloudflare tunnel was assigned to a profile, preventing automatic startup with the gateway.

**Fix:** Removed `profiles: - cloudflare` configuration. The tunnel now starts automatically and depends on the gateway's health check.

### 2. Restricted ALLOWED_HOSTS ✅
**Problem:** Host validation was too restrictive, blocking legitimate internal and external requests.

**Fix:** Updated ALLOWED_HOSTS to include:
- `localhost` - Local development
- `127.0.0.1` - Loopback interface
- `mcp-gateway` - Internal Docker service name
- `api.geminiswiss1909.online` - External domain

### 3. Healthcheck Timing ✅
**Problem:** Gateway was marked unhealthy during Kali tools initialization, causing premature container restarts.

**Fix:**
- Increased retries from 3 to 5
- Extended start_period from 30s to 60s
- Allows more time for security tools to initialize

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Cloudflare Tunnel token
- API keys for Gemini and Claude

## Multi-Environment Support 🌐

This project supports multiple Claude Code environments:

- **SWISSAI** - geminiswiss workspace (EU Central)
- **Anthropic Cloud** - Standard Anthropic workspace (US East)

### Quick Environment Switch

```bash
# Switch to SWISSAI environment
./switch-env.sh swissai

# Switch to Anthropic Cloud environment
./switch-env.sh anthropic
```

Each environment has:
- Dedicated configuration in `environments/<env>/`
- Environment-specific `.env.template`
- Custom `docker-compose.override.yml`
- Detailed documentation in `environments/<env>/README.md`

### Environment Synchronization

When working across environments:

1. **Commit changes in one environment:**
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin claude/fix-kernel-stability-1oIFj
   ```

2. **Switch to another environment in Claude Code:**
   - Click environment selector
   - Choose target environment (SWISSAI or anthropic cloud)

3. **Pull and apply configuration:**
   ```bash
   git pull origin claude/fix-kernel-stability-1oIFj
   ./switch-env.sh <target-environment>
   ```

### Claude Coordination Protocol 🤝

For seamless collaboration between Claude instances in different environments, use the **Claude Coordination Protocol (CCP)**:

```bash
# Check coordination status
./coordination/dashboard.sh

# Send message to other environment
./coordination/send-message.sh --to anthropic --subject "Status update" --body "Working on feature X"

# Sync everything
./coordination/sync-all.sh
```

Features:
- ✅ **Shared state** across environments via Google Drive
- ✅ **Asynchronous messaging** between Claude instances
- ✅ **Task coordination** and assignment
- ✅ **Real-time status** monitoring
- ✅ **MCP Gateway integration** for cross-environment communication

**Quick Start:** See [coordination/QUICKSTART.md](coordination/QUICKSTART.md)
**Full Documentation:** See [coordination/README.md](coordination/README.md)

## Setup Instructions

### 1. Clone and Configure

```bash
git clone <repository-url>
cd agentEther

# Choose your environment (swissai or anthropic)
./switch-env.sh swissai

# Edit .env with your credentials
nano .env
```

### 2. Environment Variables

Required variables in `.env`:

```env
GEMINI_API_KEY=your_gemini_api_key
CLAUDE_API_KEY=your_claude_api_key
CLOUDFLARE_TOKEN=your_tunnel_token
```

### 3. External Dependencies

Create the ChromaDB memory volume in the parent directory:

```bash
cd ..
mkdir -p chromadb-memory
cd agentEther
```

### 4. Launch the Stack

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

## Service Endpoints

| Service | Port | Description |
|---------|------|-------------|
| MCP Gateway | 3000 | Main HTTP API endpoint |
| Socket MCP | 3001 | WebSocket endpoint |
| Cloudflare Tunnel | Dynamic | Public HTTPS access |

## MCP Client Setup (Claude Desktop/Code)

This project provides two MCP servers for integration with Claude Desktop or Claude Code:

1. **MCP Gateway** - Network archaeology tools (nmap, dig, netcat, etc.)
2. **Gemini Superassistant** - Conversational AI with session management and Ollama fallback

### Quick Setup

Configure Claude Desktop to connect to the MCP servers:

**Configuration file location:**
- Linux: `~/.config/Claude/claude_desktop_config.json`
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**Configuration:**

```json
{
  "mcpServers": {
    "mcp-gateway": {
      "url": "http://localhost:3000/sse",
      "transport": "sse"
    },
    "gemini-superassistant": {
      "command": "python3",
      "args": ["/home/user/agentEther/mcp-servers/gemini-superassistant/server.py"],
      "env": {
        "GEMINI_API_KEY": "your_actual_api_key_here",
        "GEMINI_MODEL": "gemini-2.0-flash",
        "OLLAMA_URL": "http://localhost:11434"
      }
    }
  }
}
```

**Important:** Replace `your_actual_api_key_here` with your real Gemini API key from https://makersuite.google.com/app/apikey

### Available Tools

Once connected, Claude can use:
- **Network tools**: nmap, dig, whois, traceroute, netcat
- **HTTP tools**: curl, wget, whatweb
- **AI tools**: Gemini chat with persistent sessions

### Documentation

For complete setup instructions, troubleshooting, and advanced configuration, see **[MCP-SETUP.md](MCP-SETUP.md)**.

## Health Monitoring

The gateway includes a health check endpoint:

```bash
curl http://localhost:3000/health
```

Health check configuration:
- Interval: 30 seconds
- Timeout: 10 seconds
- Retries: 5
- Start period: 60 seconds

## Security Features

The gateway container includes:
- Network administration capabilities (NET_ADMIN, NET_RAW)
- Security scanning tools (nmap, tcpdump)
- Resource limits (2 CPUs, 4GB RAM)
- Isolated bridge network

## Troubleshooting

### Gateway fails health check
- Wait for full 60-second start period
- Check logs: `docker-compose logs mcp-gateway`
- Verify port 3000 is not in use

### Tunnel connection fails
- Verify CLOUDFLARE_TOKEN is valid
- Check tunnel status: `docker-compose logs cloudflare-tunnel`
- Ensure gateway is healthy before tunnel starts

### ALLOWED_HOSTS errors
- Verify hostname matches one of: localhost, 127.0.0.1, mcp-gateway, api.geminiswiss1909.online
- Check request headers for Host field

## Cloudflare Tunnel (Public Access)

The project includes Cloudflare Tunnel configuration for secure public access without opening firewall ports.

### Services Available

- **MCP Gateway**: https://api.geminiswiss1909.online
- **n8n Automation**: https://n8n.geminiswiss1909.online (optional)
- **Root Domain**: https://geminiswiss1909.online

### Quick Setup

```bash
# 1. Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
sudo mv cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared

# 2. Authenticate
cloudflared tunnel login

# 3. Use included configuration
cd cloudflare/
cloudflared tunnel --config config.yml run
```

### Configuration Files

- `cloudflare/config.yml` - Main tunnel configuration
- `cloudflare/README.md` - Complete setup guide
- `cloudflare/INDEX.md` - Navigation and reference

### Features

✅ **Free SSL/TLS** - Automatic HTTPS certificates
✅ **DDoS Protection** - Built-in Cloudflare security
✅ **No Port Forwarding** - Works behind NAT/firewall
✅ **Encrypted Tunnel** - QUIC protocol for speed and security
✅ **Multi-Service** - Single tunnel for multiple services

For detailed configuration, see `cloudflare/README.md`.

## Development

### Rebuild after changes

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### View real-time logs

```bash
docker-compose logs -f mcp-gateway
```

## Maintenance

### Update images

```bash
docker-compose pull
docker-compose up -d
```

### Clean up

```bash
docker-compose down -v  # Warning: removes volumes
```

## Contributing

Contributions are welcome! Please ensure:
1. All health checks pass
2. Security tools are properly configured
3. Documentation is updated

## License

See LICENSE file for details.

---

**Spectrum Protocol 2026** - Stabilized Kernel Architecture
*Built for reliability, security, and scalability*
