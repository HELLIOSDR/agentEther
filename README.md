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

## Setup Instructions

### 1. Clone and Configure

```bash
git clone <repository-url>
cd agentEther

# Copy environment template
cp .env.example .env

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
