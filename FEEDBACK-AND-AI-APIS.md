# Feedback System & AI APIs Integration

Complete guide for feedback channels and AI API integrations.

## 🔔 Feedback System

Multi-channel feedback and notification system for Spectrum Protocol 2026.

### Supported Channels

1. **Discord** - Real-time notifications via webhooks
2. **Slack** - Team notifications
3. **Email** - SMTP-based notifications
4. **Custom Webhook** - Any HTTP endpoint

### Quick Setup

#### 1. Discord Webhook

1. Go to your Discord server
2. Server Settings → Integrations → Webhooks → New Webhook
3. Choose channel and copy webhook URL
4. Add to `.env`:
   ```bash
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL
   ```

#### 2. Slack Webhook

1. Go to https://api.slack.com/apps
2. Create app → Incoming Webhooks → Activate
3. Add webhook to workspace and select channel
4. Copy webhook URL and add to `.env`:
   ```bash
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

#### 3. Email (Gmail Example)

1. Enable 2FA on Gmail account
2. Generate app password: https://myaccount.google.com/apppasswords
3. Add to `.env`:
   ```bash
   SMTP_SERVER=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=your.email@gmail.com
   SMTP_PASSWORD=your_app_password_here
   EMAIL_TO=recipient@example.com
   ```

### Usage

#### CLI

```bash
# Send feedback via CLI
./tools/feedback.py "Deployment Complete" "Successfully deployed to production" \
  --level success \
  --channels discord slack \
  --field "Environment:production" \
  --field "Version:2.0"

# Levels: info, success, warning, error, critical
```

#### Python API

```python
from tools.feedback import send_feedback, FeedbackLevel

# Send to all configured channels
send_feedback(
    title="MCP Gateway Down",
    message="Gateway failed health check",
    level=FeedbackLevel.ERROR,
    fields={
        "Service": "mcp-gateway",
        "Uptime": "5 minutes"
    }
)

# Send to specific channels
send_feedback(
    title="New Task Assigned",
    message="Task #123 assigned to SWISSAI",
    level=FeedbackLevel.INFO,
    channels=['discord']
)
```

### Integration with Coordination System

Feedback automatically integrated with coordination notifications:

```bash
# In coordination/notify.sh
# Automatically sends to configured channels

# Example: Task completed
./coordination/complete-task.sh task-123
# → Triggers feedback notification
```

### Integration with AlertManager

AlertManager sends alerts via feedback webhooks:

```yaml
# In monitoring/alertmanager/config.yml
receivers:
  - name: 'critical'
    webhook_configs:
      - url: 'http://host.docker.internal:9100/webhook/critical'
```

### Feedback Levels

| Level | Emoji | Use Case | Color |
|-------|-------|----------|-------|
| **info** | ℹ️ | General information | Blue |
| **success** | ✅ | Successful operations | Green |
| **warning** | ⚠️ | Non-critical issues | Yellow |
| **error** | ❌ | Errors needing attention | Red |
| **critical** | 🚨 | Critical failures | Dark Red |

---

## 🤖 AI APIs Integration

### Overview

Now you have **10 MCP servers** total:

| Server | Purpose | API |
|--------|---------|-----|
| mcp-gateway | Network tools | Custom |
| gemini-superassistant | Gemini API | Google AI |
| coordination | Multi-env coordination | Custom |
| filesystem | File operations | Official |
| git | Git operations | Official |
| github | GitHub API | Official |
| fetch | Web fetching | Official |
| grafana | Metrics query | Grafana |
| **openai-assistant** ★ | ChatGPT | OpenAI |
| **claude-api** ★ | Claude API | Anthropic |

★ = Newly added

---

## 💬 OpenAI ChatGPT Integration

### Setup

1. Get API key from https://platform.openai.com/api-keys

2. Add to `.env`:
   ```bash
   OPENAI_API_KEY=sk-your_actual_api_key_here
   OPENAI_MODEL=gpt-4-turbo-preview
   ```

3. Install dependencies:
   ```bash
   cd mcp-servers/openai-assistant
   pip install -r requirements.txt
   ```

4. Test:
   ```bash
   python3 server.py
   # (Will run in stdio mode for Claude Desktop)
   ```

### Available Models

- `gpt-4-turbo-preview` - Most capable (recommended)
- `gpt-4` - High performance
- `gpt-3.5-turbo` - Fast and cost-effective
- `gpt-3.5-turbo-16k` - Extended context

### Features

#### Session Management

```python
# Create new session
openai_create_session(session_id="research")

# Chat with history
openai_chat(
    prompt="Tell me about AI safety",
    session_id="research"
)

# List sessions
openai_list_sessions()

# Clear session (keeps system prompt)
openai_clear_session(session_id="research")

# Delete session
openai_delete_session(session_id="research")
```

#### System Prompts

```python
# Set behavior with system prompt
openai_chat(
    prompt="What's 2+2?",
    session_id="math",
    system_prompt="You are a helpful math tutor. Explain step by step."
)
```

#### Streaming

```python
# Enable streaming for long responses
openai_chat(
    prompt="Write a long story",
    stream=True
)
```

#### Temperature Control

```python
# Creative (1.5-2.0)
openai_chat(prompt="Write a poem", temperature=1.5)

# Balanced (0.7-1.0)
openai_chat(prompt="Explain quantum physics", temperature=0.7)

# Precise (0.0-0.3)
openai_chat(prompt="What is 15% of 280?", temperature=0.1)
```

### Sessions Storage

Sessions stored at: `~/.openai_mcp_sessions/`

```bash
# View sessions
ls ~/.openai_mcp_sessions/

# View session content
cat ~/.openai_mcp_sessions/research.json | jq .
```

### Pricing (as of 2026-01)

| Model | Input | Output |
|-------|-------|--------|
| gpt-4-turbo | $10/1M tokens | $30/1M tokens |
| gpt-4 | $30/1M tokens | $60/1M tokens |
| gpt-3.5-turbo | $0.50/1M tokens | $1.50/1M tokens |

---

## 🧠 Claude API Integration

### Setup

1. Get API key from https://console.anthropic.com/

2. Add to `.env`:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-your_actual_api_key_here
   CLAUDE_MODEL=claude-3-5-sonnet-20241022
   ```

3. Install dependencies:
   ```bash
   cd mcp-servers/claude-api
   pip install -r requirements.txt
   ```

### Available Models

- `claude-3-5-sonnet-20241022` - Latest, most capable (recommended)
- `claude-3-opus-20240229` - Highest performance
- `claude-3-sonnet-20240229` - Balanced
- `claude-3-haiku-20240307` - Fast and cost-effective

### Features

#### Session Management

```python
# Create new session
claude_create_session(session_id="coding")

# Chat with history
claude_chat(
    prompt="Help me debug this code",
    session_id="coding"
)

# List sessions
claude_list_sessions()

# Clear session
claude_clear_session(session_id="coding")

# Delete session
claude_delete_session(session_id="coding")
```

#### System Prompts

```python
# Set behavior
claude_chat(
    prompt="Explain recursion",
    session_id="teaching",
    system_prompt="You are a patient programming teacher."
)
```

#### Long Context

```python
# Claude supports up to 200K tokens context
claude_chat(
    prompt="Summarize this long document...",
    max_tokens=8192  # Long response
)
```

### Sessions Storage

Sessions stored at: `~/.claude_api_mcp_sessions/`

### Pricing (as of 2026-01)

| Model | Input | Output |
|-------|-------|--------|
| Claude 3.5 Sonnet | $3/1M tokens | $15/1M tokens |
| Claude 3 Opus | $15/1M tokens | $75/1M tokens |
| Claude 3 Haiku | $0.25/1M tokens | $1.25/1M tokens |

---

## 🔧 Configuration

### Claude Desktop Config

Full configuration with all 10 MCP servers:

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
        "GEMINI_API_KEY": "YOUR_ACTUAL_KEY_HERE"
      }
    },
    "coordination": {
      "command": "python3",
      "args": ["/home/user/agentEther/mcp-servers/coordination/server.py"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/user/agentEther"]
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "/home/user/agentEther"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_GITHUB_TOKEN_HERE"
      }
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "grafana": {
      "command": "npx",
      "args": ["-y", "@grafana/mcp-grafana"],
      "env": {
        "GRAFANA_URL": "http://localhost:3001",
        "GRAFANA_API_KEY": "YOUR_GRAFANA_KEY_HERE"
      }
    },
    "openai-assistant": {
      "command": "python3",
      "args": ["/home/user/agentEther/mcp-servers/openai-assistant/server.py"],
      "env": {
        "OPENAI_API_KEY": "YOUR_OPENAI_KEY_HERE"
      }
    },
    "claude-api": {
      "command": "python3",
      "args": ["/home/user/agentEther/mcp-servers/claude-api/server.py"],
      "env": {
        "ANTHROPIC_API_KEY": "YOUR_ANTHROPIC_KEY_HERE"
      }
    }
  }
}
```

**IMPORTANT**: Replace `YOUR_*_KEY_HERE` with actual API keys!

### Configuration Locations

- **Linux**: `~/.config/Claude/claude_desktop_config.json`
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

---

## 📊 Use Cases

### Use Case 1: Multi-Model Comparison

Compare responses from different AI models:

```python
# Ask same question to all models
question = "Explain quantum entanglement"

# Gemini
gemini_chat(prompt=question, session_id="compare")

# OpenAI GPT-4
openai_chat(prompt=question, session_id="compare")

# Claude 3.5
claude_chat(prompt=question, session_id="compare")
```

### Use Case 2: Specialized Tasks

Use different models for different tasks:

```python
# Code generation → OpenAI (excellent at code)
openai_chat(
    prompt="Write a Python function to sort a list",
    model="gpt-4-turbo-preview"
)

# Long document analysis → Claude (200K context)
claude_chat(
    prompt="Summarize this 50-page document...",
    max_tokens=8192
)

# Quick queries → Gemini (free tier available)
gemini_chat(
    prompt="What's the weather API endpoint?",
    model="gemini-2.0-flash"
)
```

### Use Case 3: Feedback on Deployment

```bash
# Deployment success
./tools/feedback.py \
  "Deployment Successful" \
  "Version 2.0 deployed to production" \
  --level success \
  --field "Version:2.0" \
  --field "Environment:production" \
  --field "Duration:5m30s"

# Critical error
./tools/feedback.py \
  "Database Connection Failed" \
  "PostgreSQL connection timeout after 30s" \
  --level critical \
  --field "Service:database" \
  --field "Error:Connection timeout"
```

### Use Case 4: Coordination with AI

```python
# Use AI to analyze coordination state
openai_chat(
    prompt="Analyze this coordination state and suggest improvements",
    system_prompt="You are a DevOps expert analyzing system state"
)

# Get AI to generate tasks
claude_chat(
    prompt="Generate a task breakdown for implementing feature X",
    system_prompt="You are a project manager creating actionable tasks"
)
```

---

## 🔒 Security Best Practices

### API Keys

✅ **DO**:
- Store in `.env` (gitignored)
- Use environment variables
- Rotate keys regularly
- Use different keys for dev/prod
- Monitor API usage

❌ **DON'T**:
- Commit keys to git
- Share keys in chat/email
- Use production keys in development
- Hardcode keys in source files

### Rate Limiting

All MCP servers have built-in error handling for rate limits:

```python
# Automatic rate limit handling
try:
    response = openai_chat(prompt="...")
except RateLimitError:
    # Waits and retries
    pass
```

### Cost Management

Monitor API usage:

```bash
# OpenAI Dashboard
https://platform.openai.com/usage

# Anthropic Console
https://console.anthropic.com/

# Gemini Dashboard
https://makersuite.google.com/
```

---

## 🧪 Testing

### Test Feedback System

```bash
# Test all channels
./tools/feedback.py "Test Message" "Testing feedback system" \
  --level info \
  --channels discord slack email

# Should show:
# Results:
#   ✅ discord
#   ✅ slack
#   ✅ email
```

### Test OpenAI

```bash
cd mcp-servers/openai-assistant
python3 -c "
from server import call_openai
import asyncio

response = asyncio.run(call_openai([
    {'role': 'user', 'content': 'Hello, are you working?'}
]))
print(response)
"
```

### Test Claude API

```bash
cd mcp-servers/claude-api
python3 -c "
from server import call_claude
import asyncio

response = asyncio.run(call_claude([
    {'role': 'user', 'content': 'Hello, are you working?'}
]))
print(response)
"
```

---

## 📚 Documentation

- [MCP Setup Guide](MCP-SETUP.md) - Complete MCP configuration
- [Monitoring Guide](monitoring/README.md) - Prometheus + Grafana
- [Coordination Protocol](coordination/README.md) - Multi-environment coordination
- [Autonomous Report](AUTONOMOUS-IMPLEMENTATION.md) - Full implementation details

---

## 🎯 Quick Commands

```bash
# Send Discord notification
./tools/feedback.py "Title" "Message" --level success --channels discord

# Chat with OpenAI (requires Claude Desktop running)
# Via Claude Desktop: "Use OpenAI to explain quantum physics"

# Chat with Claude API
# Via Claude Desktop: "Use Claude API to debug this code"

# List all AI sessions
# Via Claude Desktop: "List all OpenAI sessions"
# Via Claude Desktop: "List all Claude API sessions"

# Check API configuration
grep -E "OPENAI|ANTHROPIC|GEMINI" .env
```

---

**Spectrum Protocol 2026** - Multi-Channel Feedback + Multi-Model AI
*Choose the right tool for the right job*
