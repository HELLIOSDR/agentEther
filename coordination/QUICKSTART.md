# Claude Coordination Protocol - Quick Start

## 🚀 5-Minute Setup

### Step 1: Initial State

Check current coordination status:

```bash
cd /home/user/agentEther
./coordination/dashboard.sh
```

### Step 2: Update Your Status

Let other environments know you're active:

```bash
./coordination/update-state.sh --status active --task "testing-coordination"
```

### Step 3: Sync to Google Drive

```bash
./sync-gdrive.sh
```

### Step 4: Check Messages

```bash
./coordination/read-messages.sh --unread
```

## 📋 Common Tasks

### Send a Message

```bash
./coordination/send-message.sh \
  --to anthropic \
  --subject "Need help with cloudflare" \
  --body "Can you check if cloudflared is running on host?"

./sync-gdrive.sh
```

### Check for Tasks

```bash
./coordination/check-tasks.sh
```

### One-Command Sync

```bash
# Does everything: heartbeat + sync + check messages + check tasks
./coordination/sync-all.sh
```

## 🔄 Typical Workflow

### Start of Work Session

```bash
# 1. Pull latest from Google Drive
./sync-gdrive.sh

# 2. Check dashboard
./coordination/dashboard.sh

# 3. Read unread messages
./coordination/read-messages.sh --unread

# 4. Check assigned tasks
./coordination/check-tasks.sh

# 5. Update your status
./coordination/update-state.sh --status active --task "implementing-feature-x"
./sync-gdrive.sh
```

### During Work

```bash
# Every 5-10 minutes, run sync to stay coordinated
./coordination/sync-all.sh
```

### End of Work Session

```bash
# Update status to idle
./coordination/update-state.sh --status idle --task ""
./sync-gdrive.sh
```

## 💡 Pro Tips

### Automatic Background Sync

Run in background terminal:

```bash
# Auto-sync every 5 minutes
watch -n 300 './coordination/sync-all.sh'
```

### Quick Status Check

```bash
# Just the dashboard
./coordination/dashboard.sh

# Or check specific environment
jq '.environments.anthropic' coordination/state.json
```

### Send High Priority Message

```bash
./coordination/send-message.sh \
  --to all \
  --subject "URGENT: Service Down" \
  --body "MCP Gateway is not responding" \
  --priority urgent

./sync-gdrive.sh
```

## 🎯 Example Scenarios

### Scenario 1: Need Help from Other Environment

```bash
# SWISSAI environment
./coordination/send-message.sh \
  --to anthropic \
  --subject "Can you restart cloudflared?" \
  --body "I don't have systemd access. Can you SSH to host and run: sudo systemctl restart cloudflared-geminiswiss.service"

./sync-gdrive.sh
```

### Scenario 2: Notify About Completed Work

```bash
# After finishing feature
git push origin claude/feature-x

./coordination/send-message.sh \
  --to all \
  --subject "Feature X Complete" \
  --body "Implemented feature X and pushed to branch claude/feature-x. Ready for review."

./coordination/update-state.sh --status idle
./sync-gdrive.sh
```

### Scenario 3: Coordinate on Shared Resource

```bash
# Before modifying docker-compose.yml
./coordination/send-message.sh \
  --to all \
  --subject "Updating docker-compose" \
  --body "I'm updating docker-compose.yml. Please don't modify it for the next 30 minutes."

# Do your work
vim docker-compose.yml
git commit -m "Update docker-compose"
git push

# Notify when done
./coordination/send-message.sh \
  --to all \
  --subject "Docker-compose updated" \
  --body "Changes pushed. Please pull and review."

./sync-gdrive.sh
```

## 🔍 Monitoring

### Watch for Changes

```bash
# Monitor state file for changes
watch -n 10 'jq .environments coordination/state.json'

# Monitor for new messages
watch -n 30 './coordination/read-messages.sh --unread'
```

### Check Last Sync Time

```bash
jq '.statistics' coordination/state.json
```

## 🐛 Troubleshooting

### Messages Not Syncing

```bash
# Check rclone connection
rclone lsd agentether-gdrive:

# Force sync
./sync-gdrive.sh --dry-run  # Check what would sync
./sync-gdrive.sh            # Actually sync

# Check if messages exist locally
ls -la coordination/messages/
```

### State File Conflicts

```bash
# If state.json has conflicts after sync
cat coordination/state.json

# Backup current state
cp coordination/state.json coordination/state.json.backup

# Pull fresh from Google Drive
./sync-gdrive.sh

# Merge manually if needed
vimdiff coordination/state.json coordination/state.json.backup
```

### Dashboard Not Working

```bash
# Check if jq is installed
which jq

# Check if state file exists
ls -la coordination/state.json

# Try running directly
bash ./coordination/dashboard.sh
```

## 📚 Next Steps

- Read full documentation: [coordination/README.md](README.md)
- Configure notifications (optional)
- Set up automatic sync cron job
- Create custom templates for common messages

## 🎓 Learning More

```bash
# View current configuration
cat coordination/config.json

# View state structure
jq '.' coordination/state.json

# Check available scripts
ls -la coordination/*.sh
```

---

**Claude Coordination Protocol** - Making multi-environment collaboration seamless!
