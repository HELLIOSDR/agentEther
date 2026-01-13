# Claude Coordination Protocol (CCP)

## Overview

System współpracy między różnymi instancjami Claude Code w różnych środowiskach (SWISSAI, Anthropic Cloud, lokalne CLI).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Google Drive (Shared State)                │
│         Folder: 1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo      │
│                  coordination/                          │
│                  ├── state.json                         │
│                  ├── tasks.json                         │
│                  └── messages/                          │
└────────────┬────────────────────────────┬───────────────┘
             │                            │
             │ rclone sync                │ rclone sync
             ▼                            ▼
    ┌──────────────────┐        ┌──────────────────┐
    │  SWISSAI (EU)    │        │ Anthropic (US)   │
    │  Claude Code     │◄──────►│  Claude Code     │
    │                  │  MCP   │                  │
    └────────┬─────────┘        └────────┬─────────┘
             │                            │
             └────────────┬───────────────┘
                          ▼
              ┌────────────────────────┐
              │   MCP Gateway (3000)   │
              │   Cloudflare Tunnel    │
              │ api.geminiswiss1909... │
              └────────────────────────┘
                          │
                          ▼
              ┌────────────────────────┐
              │   ChromaDB (8001)      │
              │   Shared Memory Store  │
              └────────────────────────┘
```

## Communication Channels

### 1. Shared State File (Primary)

**Path**: `coordination/state.json` (synchronized via Google Drive)

**Structure**:
```json
{
  "version": "1.0.0",
  "lastUpdate": "2026-01-13T10:00:00Z",
  "environments": {
    "swissai": {
      "status": "active",
      "lastSeen": "2026-01-13T10:00:00Z",
      "currentTask": "fixing-cloudflare-tunnel",
      "branch": "claude/fix-kernel-stability-1oIFj",
      "commit": "48559cc"
    },
    "anthropic": {
      "status": "idle",
      "lastSeen": "2026-01-13T09:45:00Z",
      "currentTask": null,
      "branch": "claude/fix-kernel-stability-1oIFj",
      "commit": "48559cc"
    }
  },
  "sharedContext": {
    "projectName": "agentEther",
    "protocol": "Spectrum Protocol 2026",
    "mcpGatewayUrl": "https://api.geminiswiss1909.online",
    "chromaDbEnabled": true
  },
  "activeIssues": [
    {
      "id": "cloudflare-restart",
      "priority": "high",
      "assignedTo": "swissai",
      "status": "in_progress",
      "description": "Restart cloudflared service on host"
    }
  ]
}
```

**Update frequency**: Every 5 minutes via rclone sync

### 2. Task Queue

**Path**: `coordination/tasks.json`

**Purpose**: Coordinate work between environments

```json
{
  "tasks": [
    {
      "id": "task-001",
      "title": "Implement feature X",
      "status": "pending",
      "priority": 1,
      "assignedTo": null,
      "createdBy": "swissai",
      "createdAt": "2026-01-13T09:00:00Z",
      "dependencies": [],
      "branch": "claude/feature-x"
    }
  ]
}
```

### 3. Message Board

**Path**: `coordination/messages/*.json`

**Purpose**: Asynchronous messages between environments

```json
{
  "id": "msg-12345",
  "from": "swissai",
  "to": "anthropic",
  "timestamp": "2026-01-13T10:00:00Z",
  "type": "request",
  "subject": "Need help with cloudflare tunnel",
  "body": "Can you check if cloudflared is running on the host?",
  "attachments": [],
  "status": "unread"
}
```

### 4. MCP Gateway (Real-time)

**URL**: https://api.geminiswiss1909.online/sse

**Purpose**: Real-time tool execution and coordination

Both environments can:
- Execute network tools (nmap, dig, etc.)
- Query shared ChromaDB
- Trigger actions via MCP

### 5. ChromaDB (Shared Memory)

**URL**: http://localhost:8001

**Purpose**: Shared knowledge base

- Store project context
- Share discovered information
- Maintain conversation history
- Index documentation

## Usage Patterns

### Pattern 1: Task Handoff

**SWISSAI Environment:**
```bash
# Create task for Anthropic environment
./coordination/send-task.sh \
  --title "Run tests on US servers" \
  --assign anthropic \
  --priority high

# Sync to Google Drive
./sync-gdrive.sh
```

**Anthropic Environment:**
```bash
# Pull latest tasks
./sync-gdrive.sh

# Check for assigned tasks
./coordination/check-tasks.sh

# Accept task
./coordination/accept-task.sh task-001
```

### Pattern 2: State Synchronization

**Any Environment:**
```bash
# Update current state
./coordination/update-state.sh \
  --status active \
  --task "implementing-feature-x" \
  --commit $(git rev-parse --short HEAD)

# Sync to Drive
./sync-gdrive.sh

# In other environment
./sync-gdrive.sh
./coordination/get-state.sh swissai
```

### Pattern 3: Asynchronous Messages

**Send message:**
```bash
./coordination/send-message.sh \
  --to anthropic \
  --subject "Cloudflare tunnel status" \
  --body "Tunnel restarted successfully"
```

**Read messages:**
```bash
./coordination/read-messages.sh --unread
```

### Pattern 4: MCP-based Coordination

**Query from any environment via Claude:**

```
User: "What's the current status in the SWISSAI environment?"

Claude uses MCP Gateway to:
1. Fetch coordination/state.json from ChromaDB
2. Parse current status
3. Return information
```

## Helper Scripts

### `coordination/sync-state.sh`

Automatically sync state every 5 minutes:

```bash
#!/bin/bash
while true; do
  ./sync-gdrive.sh
  ./coordination/update-state.sh --heartbeat
  sleep 300
done
```

### `coordination/update-state.sh`

Update local state and push to Drive:

```bash
#!/bin/bash
# Updates state.json with current environment status
```

### `coordination/check-tasks.sh`

Check for assigned tasks:

```bash
#!/bin/bash
# Lists tasks assigned to current environment
```

### `coordination/send-message.sh`

Send message to another environment:

```bash
#!/bin/bash
# Creates message in messages/ directory
```

## Configuration

### Per-environment config

**`coordination/config.json`**:

```json
{
  "environmentName": "swissai",
  "syncInterval": 300,
  "mcpGatewayUrl": "https://api.geminiswiss1909.online",
  "chromaDbUrl": "http://localhost:8001",
  "gdriveRemote": "agentether-gdrive",
  "coordinationPath": "coordination/"
}
```

## Security

### Access Control

- Google Drive folder shared only between authorized accounts
- MCP Gateway protected by Cloudflare Access (optional)
- State files are JSON (no executable code)
- Message validation before processing

### Encryption

Optional end-to-end encryption for sensitive messages:

```bash
# Encrypt message
./coordination/send-message.sh --encrypt --key ~/.coordination.key

# Decrypt message
./coordination/read-messages.sh --decrypt --key ~/.coordination.key
```

## Best Practices

### 1. Always Sync Before Starting Work

```bash
# At start of session
./sync-gdrive.sh
./coordination/check-tasks.sh
./coordination/read-messages.sh --unread
```

### 2. Update State Regularly

```bash
# When starting task
./coordination/update-state.sh --task "task-name" --status active

# When finishing
./coordination/update-state.sh --status idle

# Push to Drive
./sync-gdrive.sh
```

### 3. Coordinate on Shared Resources

Before working on:
- Docker Compose services
- Cloudflare Tunnel configuration
- Shared databases

Check state to ensure no conflicts.

### 4. Use Message Board for Complex Communication

For anything beyond simple state updates, use messages:

```bash
./coordination/send-message.sh \
  --to anthropic \
  --subject "Need review on PR #123" \
  --body "Please review changes to MCP Gateway configuration"
```

## Conflict Resolution

### Merge Conflicts

If both environments modify same files:

1. **State file conflicts**: Last-write-wins, use timestamps
2. **Task queue conflicts**: Merge arrays, deduplicate by ID
3. **Message conflicts**: No conflicts (timestamped files)

### Lock Mechanism

For critical operations:

```bash
# Acquire lock
./coordination/lock.sh acquire cloudflare-config

# Do work
...

# Release lock
./coordination/lock.sh release cloudflare-config
```

## Monitoring

### Dashboard

View coordination status:

```bash
./coordination/dashboard.sh
```

Output:
```
╔═══════════════════════════════════════════════════════╗
║        Claude Coordination Protocol Status            ║
╠═══════════════════════════════════════════════════════╣
║  Environment    │ Status  │ Last Seen  │ Task         ║
║─────────────────┼─────────┼────────────┼─────────────║
║  swissai        │ active  │ 1 min ago  │ cloudflare  ║
║  anthropic      │ idle    │ 15 min ago │ -           ║
╠═══════════════════════════════════════════════════════╣
║  Active Tasks: 1                                      ║
║  Unread Messages: 2                                   ║
║  Last Sync: 30 seconds ago                           ║
╚═══════════════════════════════════════════════════════╝
```

### Alerts

```bash
# Set up alert when other environment needs attention
./coordination/watch.sh --alert-on-message
```

## Troubleshooting

### State file not syncing

```bash
# Check rclone status
./sync-gdrive.sh --dry-run

# Force sync
./sync-gdrive.sh --force

# Check Google Drive connection
rclone lsd agentether-gdrive:
```

### Messages not appearing

```bash
# Check sync status
./coordination/debug.sh

# Verify message files
ls -la coordination/messages/

# Manual sync
./sync-gdrive.sh
```

### Conflicts in state.json

```bash
# View conflict markers
cat coordination/state.json

# Resolve by keeping newer version
./coordination/resolve-conflicts.sh --keep-newer

# Or manually edit
nano coordination/state.json
```

## Advanced: MCP-based Coordination

### Query coordination state via MCP

```python
# In Claude Desktop or Claude Code
# Claude can automatically query coordination state

User: "What is the anthropic environment working on?"

# Claude uses MCP Gateway to:
# 1. Read coordination/state.json from ChromaDB
# 2. Parse status
# 3. Return: "The anthropic environment is idle, last seen 15 minutes ago"
```

### Trigger actions remotely

```python
# Via Gemini Superassistant MCP server
# Create session for coordination

User: "Tell the swissai environment to restart the tunnel"

# Claude:
# 1. Creates message via coordination/send-message.sh
# 2. Syncs to Google Drive
# 3. SWISSAI environment picks it up on next sync
```

## Integration with Existing Tools

### With switch-env.sh

```bash
# Automatically sync when switching environments
./switch-env.sh swissai
./coordination/sync-state.sh
```

### With docker-compose

```bash
# Before starting services
./coordination/lock.sh acquire docker-services
docker-compose up -d
./coordination/lock.sh release docker-services
```

### With Git workflow

```bash
# Coordinate on branches
./coordination/update-state.sh \
  --branch $(git branch --show-current) \
  --commit $(git rev-parse --short HEAD)
```

## Examples

### Example 1: Distributed Testing

**SWISSAI** runs tests in EU:
```bash
./coordination/update-state.sh --task "testing-eu-servers"
pytest tests/eu/
./coordination/send-message.sh --to anthropic --body "EU tests passed"
```

**Anthropic** runs tests in US:
```bash
./sync-gdrive.sh
./coordination/read-messages.sh
./coordination/update-state.sh --task "testing-us-servers"
pytest tests/us/
```

### Example 2: Configuration Changes

**SWISSAI** wants to update docker-compose:
```bash
# Check if anyone else is working on it
./coordination/check-locks.sh docker-compose

# Acquire lock
./coordination/lock.sh acquire docker-compose

# Make changes
vim docker-compose.yml

# Commit and notify
git commit -m "Update docker-compose"
git push
./coordination/send-message.sh --to all --body "Docker compose updated, please pull"

# Release lock
./coordination/lock.sh release docker-compose
```

### Example 3: Troubleshooting Together

**SWISSAI** encounters issue:
```bash
./coordination/send-message.sh \
  --to anthropic \
  --priority high \
  --subject "Cloudflare tunnel down" \
  --body "Can't restart cloudflared service. System has no systemd. Need help from host."
```

**Anthropic** responds:
```bash
./sync-gdrive.sh
./coordination/read-messages.sh --unread
# Reads message, investigates
./coordination/send-message.sh \
  --to swissai \
  --reply-to msg-12345 \
  --body "Docker Compose is the way. Run: docker compose restart cloudflare-tunnel"
```

## Future Enhancements

- [ ] Web dashboard for coordination status
- [ ] Real-time WebSocket notifications
- [ ] Automatic conflict resolution
- [ ] Integration with GitHub Issues/PRs
- [ ] Voice/video call coordination via MCP
- [ ] AI-powered task distribution
- [ ] Encrypted backup of coordination state

---

**Claude Coordination Protocol v1.0**
*Enabling multi-environment collaboration for Claude Code*
