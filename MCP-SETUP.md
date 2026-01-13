# MCP Servers Setup Guide

## Overview

This project includes two MCP (Model Context Protocol) servers:

1. **MCP Gateway** - Network archaeology tools (nmap, dig, netcat, etc.)
2. **Gemini Superassistant** - Conversational AI with session management and Ollama fallback

## Architecture

```
┌─────────────────────────────────────────────────────┐
│            Claude Desktop / Claude Code             │
│                   MCP Client                        │
└────────────────┬────────────────┬───────────────────┘
                 │                │
                 │ SSE            │ stdio
                 ▼                ▼
    ┌────────────────────┐  ┌──────────────────────┐
    │   MCP Gateway      │  │ Gemini Superassistant│
    │   Port 3000        │  │ Python Script        │
    │   Network Tools    │  │ Session Management   │
    └────────────────────┘  └──────────────────────┘
                 │                │
                 │                ├─► Gemini API
                 │                └─► Ollama (fallback)
                 │
                 ├─► Kali Tools (nmap, dig, etc.)
                 └─► ChromaDB
```

## Prerequisites

### 1. API Keys

Get your API keys:
- **Gemini API**: https://makersuite.google.com/app/apikey
- **Anthropic Claude API** (optional): https://console.anthropic.com/

### 2. Running Services

Ensure services are running:

```bash
# Start all services
docker-compose up -d

# Verify MCP Gateway is running
curl http://localhost:3000/health

# Verify Ollama (optional - for Gemini fallback)
curl http://localhost:11434/api/tags
```

### 3. Python Dependencies (for Gemini Superassistant)

```bash
# Install Python dependencies
cd mcp-servers/gemini-superassistant
pip install -r requirements.txt
```

## Configuration for Claude Desktop

### Location

Claude Desktop MCP configuration file location:

- **Linux**: `~/.config/Claude/claude_desktop_config.json`
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

### Configuration File

Create or edit the configuration file:

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
        "API_BASE_URL": "https://generativelanguage.googleapis.com/v1beta",
        "GEMINI_API_KEY": "YOUR_ACTUAL_GEMINI_API_KEY",
        "GEMINI_MODEL": "gemini-2.0-flash",
        "GEMINI_TIMEOUT_MS": "60000",
        "OLLAMA_URL": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3.2:3b"
      }
    }
  }
}
```

**IMPORTANT**: Replace `YOUR_ACTUAL_GEMINI_API_KEY` with your real API key!

### Path Adjustments

If you're on a different system, adjust the path:

```json
{
  "gemini-superassistant": {
    "command": "python3",
    "args": ["/absolute/path/to/agentEther/mcp-servers/gemini-superassistant/server.py"],
    // ...
  }
}
```

For the user in the provided config (`/home/a/`):

```bash
# Create symlink from expected location to actual location
ln -s /home/user/agentEther/mcp-servers/gemini-superassistant/server.py /home/a/gemini_superassistant_mcp.py
```

## Quick Setup

### 1. Copy Configuration Template

```bash
# Copy the template
cp config/claude-desktop-config.json ~/.config/Claude/claude_desktop_config.json

# Or on macOS
cp config/claude-desktop-config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### 2. Add Your API Key

Edit the configuration file and replace `${GEMINI_API_KEY}` with your actual key:

```bash
# Linux
nano ~/.config/Claude/claude_desktop_config.json

# macOS
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### 3. Restart Claude Desktop

Close and reopen Claude Desktop to load the new configuration.

### 4. Verify Connection

In Claude Desktop, you should see the MCP servers connected:
- 🟢 `mcp-gateway` - Network tools available
- 🟢 `gemini-superassistant` - Gemini chat available

## MCP Gateway Tools

Once connected, Claude Desktop can use these tools:

### Network Scanning
- `nmap_scan` - Port scanning and host discovery
- `traceroute` - Network path tracing

### DNS & Domain
- `dig_lookup` - DNS queries (A, MX, TXT, etc.)
- `whois_lookup` - Domain registration info

### HTTP Testing
- `curl_request` - HTTP requests with full control
- `wget_download` - Download files
- `whatweb_scan` - Web technology fingerprinting

### Network Communication
- `netcat_connect` - Raw TCP/UDP connections

## Gemini Superassistant Tools

### Session Management
- `create_session` - Create new chat session
- `list_sessions` - List all sessions
- `clear_session` - Clear session history

### Chat
- `gemini_chat` - Chat with Gemini (auto-fallback to Ollama on quota exceeded)

### Example Usage

```bash
# In Claude Desktop, ask:
"Can you create a new Gemini session called 'research' and then chat about AI safety?"

# Claude will:
1. Call create_session(session_id="research")
2. Call gemini_chat(session_id="research", prompt="Let's discuss AI safety")
3. Return the response
```

## Session Persistence

Gemini Superassistant stores sessions at:

```
~/.gemini_mcp_sessions/
├── research.json
├── coding.json
└── default.json
```

Each session maintains conversation history across restarts.

## Ollama Fallback

When Gemini API quota is exceeded (429 error), the server automatically falls back to local Ollama:

1. **Install Ollama**:
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

2. **Pull a model**:
   ```bash
   ollama pull llama3.2:3b
   ```

3. **Start Ollama**:
   ```bash
   ollama serve
   ```

The fallback is automatic - no configuration needed!

## Troubleshooting

### MCP Gateway Not Connecting

```bash
# Check if gateway is running
docker-compose ps mcp-gateway

# View logs
docker-compose logs mcp-gateway

# Restart
docker-compose restart mcp-gateway

# Test endpoint
curl http://localhost:3000/health
```

### Gemini Superassistant Not Starting

```bash
# Check Python path
which python3

# Test script manually
python3 /home/user/agentEther/mcp-servers/gemini-superassistant/server.py

# Check dependencies
pip list | grep mcp
pip list | grep httpx
```

### API Key Issues

```bash
# Verify API key is set
grep GEMINI_API_KEY ~/.config/Claude/claude_desktop_config.json

# Test Gemini API directly
curl -H "x-goog-api-key: YOUR_KEY" \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"test"}]}]}'
```

### Claude Desktop Not Showing MCP Servers

1. **Check configuration file location**:
   ```bash
   # Linux
   cat ~/.config/Claude/claude_desktop_config.json

   # macOS
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

2. **Validate JSON syntax**:
   ```bash
   # Use jq to validate
   cat ~/.config/Claude/claude_desktop_config.json | jq .
   ```

3. **Check Claude Desktop logs**:
   - Linux: `~/.config/Claude/logs/`
   - macOS: `~/Library/Logs/Claude/`
   - Windows: `%APPDATA%\Claude\logs\`

4. **Restart Claude Desktop completely**:
   - Close all Claude windows
   - Kill background process if needed
   - Reopen Claude Desktop

## Environment Variables

### MCP Gateway (via .env file)

```bash
# In /home/user/agentEther/.env
GEMINI_API_KEY=your_key_here
ANTHROPIC_API_KEY=your_key_here
ALLOWED_HOSTS=localhost,127.0.0.1,mcp-gateway,geminiswiss1909.online,api.geminiswiss1909.online
```

### Gemini Superassistant (via Claude Desktop config)

Set in `claude_desktop_config.json`:
- `GEMINI_API_KEY` - Your Gemini API key
- `GEMINI_MODEL` - Model to use (gemini-2.0-flash, gemini-2.5-pro)
- `GEMINI_TIMEOUT_MS` - Request timeout (default: 60000)
- `OLLAMA_URL` - Ollama API endpoint (default: http://localhost:11434)
- `OLLAMA_MODEL` - Ollama model for fallback (default: llama3.2:3b)

## Security Notes

### API Key Protection

✅ **DO**:
- Store API keys in Claude Desktop config (not committed to git)
- Use environment variables where possible
- Keep `.env` file in `.gitignore`
- Use different keys for dev/prod

❌ **DON'T**:
- Commit API keys to git
- Share API keys in chat/email
- Use production keys in development
- Hardcode keys in source files

### Network Security

The MCP Gateway has network scanning capabilities. Use responsibly:

- ✅ Only scan networks you own or have permission to scan
- ✅ Use rate limiting (configured in `config/mcp.json`)
- ✅ Keep logs for audit trail
- ❌ Don't scan public networks without authorization
- ❌ Don't use for malicious purposes

## Advanced Configuration

### Custom Ollama Models

```json
{
  "gemini-superassistant": {
    "env": {
      "OLLAMA_MODEL": "mixtral:8x7b",  // Larger model
      // or
      "OLLAMA_MODEL": "phi3:mini"      // Smaller, faster
    }
  }
}
```

### Adjust Timeouts

```json
{
  "gemini-superassistant": {
    "env": {
      "GEMINI_TIMEOUT_MS": "120000"  // 2 minutes for long requests
    }
  }
}
```

### Multiple Instances

Run multiple Gemini instances with different configs:

```json
{
  "mcpServers": {
    "gemini-fast": {
      "command": "python3",
      "args": ["/path/to/server.py"],
      "env": {
        "GEMINI_MODEL": "gemini-2.0-flash",
        "GEMINI_TIMEOUT_MS": "30000"
      }
    },
    "gemini-smart": {
      "command": "python3",
      "args": ["/path/to/server.py"],
      "env": {
        "GEMINI_MODEL": "gemini-2.5-pro",
        "GEMINI_TIMEOUT_MS": "120000"
      }
    }
  }
}
```

## Testing

### Test MCP Gateway

```bash
# Via curl
curl -X POST http://localhost:3000/sse \
  -H "Content-Type: application/json" \
  -d '{"tool": "dig_lookup", "args": {"domain": "google.com"}}'

# Via Docker logs
docker-compose logs -f mcp-gateway
```

### Test Gemini Superassistant

```bash
# Run manually with test input
cd mcp-servers/gemini-superassistant
python3 server.py
# (Then send MCP protocol messages via stdin)

# Check session storage
ls -la ~/.gemini_mcp_sessions/

# View session content
cat ~/.gemini_mcp_sessions/default.json | jq .
```

## Integration with Cloudflare Tunnel

The MCP Gateway is accessible via Cloudflare Tunnel:

- **Public URL**: https://api.geminiswiss1909.online/sse
- **Private URL**: http://localhost:3000/sse

For remote access, update Claude Desktop config:

```json
{
  "mcp-gateway": {
    "url": "https://api.geminiswiss1909.online/sse",
    "transport": "sse"
  }
}
```

See `cloudflare/README.md` for tunnel configuration.

## Performance

### Expected Latency

- **MCP Gateway**: < 100ms (local tools)
- **Gemini Superassistant**: 1-3s (Gemini API), < 1s (Ollama fallback)

### Rate Limits

- **MCP Gateway**: 100 requests/minute (configurable in `config/mcp.json`)
- **Gemini API**: 60 requests/minute (free tier)
- **Ollama**: No rate limit (local)

## Support

### Documentation
- **Main README**: `README.md`
- **Environment Setup**: `ENVIRONMENTS.md`
- **Cloudflare Tunnel**: `cloudflare/README.md`
- **Google Drive Sync**: `GDRIVE-SYNC.md`

### Logs
- **MCP Gateway**: `docker-compose logs mcp-gateway`
- **Gemini Superassistant**: Check Claude Desktop logs
- **Cloudflare Tunnel**: `sudo journalctl -u cloudflared-geminiswiss.service`

### Health Checks
```bash
# MCP Gateway
curl http://localhost:3000/health

# Docker services
docker-compose ps

# Ollama
curl http://localhost:11434/api/tags
```

---

**Spectrum Protocol 2026** - MCP Servers Setup
*Network archaeology meets conversational AI*
