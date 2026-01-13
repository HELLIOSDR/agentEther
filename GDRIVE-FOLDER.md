# Google Drive Folder Configuration

## Your Google Drive Folder

**Folder ID:** `1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo`

**Direct Link:** https://drive.google.com/drive/folders/1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo

## Quick Setup

### Option 1: Automated Setup (Recommended)

```bash
./setup-gdrive.sh
```

This script will:
- Check if rclone is installed
- Guide you through configuration
- Use your specific Google Drive folder
- Test the connection

### Option 2: Manual Configuration

```bash
# 1. Start rclone config
rclone config

# 2. Create new remote
# Choose: n (New remote)
# Name: agentether-gdrive

# 3. Choose Google Drive
# Storage: drive

# 4. Use your specific folder
# root_folder_id: 1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo

# 5. Complete OAuth flow
# Follow browser prompts to authorize

# 6. Test connection
rclone lsd agentether-gdrive:
```

## First Sync

### Preview What Will Be Synced

```bash
./sync-gdrive.sh backup --dry-run
```

This shows you exactly what files will be uploaded without actually uploading anything.

### Perform First Backup

```bash
./sync-gdrive.sh backup
```

This uploads your agentEther project to your Google Drive folder.

## Verify Sync

### Check Files on Google Drive

```bash
# List top-level contents
./sync-gdrive.sh list

# Or directly with rclone
rclone tree agentether-gdrive:
```

### Open in Browser

Visit: https://drive.google.com/drive/folders/1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo

You should see:
```
agentEther/
├── docker-compose.yml
├── Dockerfile
├── .env.example
├── README.md
├── ENVIRONMENTS.md
├── GDRIVE-SYNC.md
├── switch-env.sh
├── sync-gdrive.sh
├── environments/
├── config/
├── cloudflare/
└── ... (other project files)
```

## What Gets Synced

✅ **Included:**
- Source code
- Configuration templates (`.env.example`, `.env.template`)
- Docker files
- Documentation
- Scripts
- Environment configurations

❌ **Excluded:** (see `.rcloneignore`)
- `.env` files (secrets!)
- Logs (`*.log`)
- `node_modules/`
- `.git/` directory
- Docker runtime files
- Large data (`chromadb-memory/`)

## Folder Structure on Google Drive

After sync, your Google Drive will contain:

```
Your Google Drive
└── agentEther/  (Folder ID: 1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo)
    ├── docker-compose.yml
    ├── Dockerfile
    ├── .env.example
    ├── .gitignore
    ├── .rcloneignore
    ├── README.md
    ├── ENVIRONMENTS.md
    ├── GDRIVE-SYNC.md
    ├── switch-env.sh
    ├── sync-gdrive.sh
    ├── setup-gdrive.sh
    ├── environments/
    │   ├── swissai/
    │   │   ├── .env.template
    │   │   ├── docker-compose.override.yml
    │   │   └── README.md
    │   └── anthropic/
    │       ├── .env.template
    │       ├── docker-compose.override.yml
    │       └── README.md
    ├── config/
    │   ├── mcp.json
    │   └── .gitkeep
    ├── cloudflare/
    │   ├── config.yml
    │   ├── QUICKSTART.md
    │   ├── README.md
    │   └── INDEX.md
    ├── logs/
    │   └── .gitkeep  (logs excluded, but structure preserved)
    └── data/
        └── .gitkeep  (data excluded, but structure preserved)
```

## Restore from This Folder

If you need to restore your project from Google Drive:

```bash
# 1. Clone git repository (for git history)
git clone <your-repo-url>
cd agentEther

# 2. Restore files from Google Drive
./sync-gdrive.sh restore

# 3. Configure credentials manually
nano .env  # Add your API keys

# 4. Verify
docker-compose config
```

## Sync Strategies

### Daily Backup

```bash
# After making changes
git add .
git commit -m "Your changes"
git push origin claude/fix-kernel-stability-1oIFj
./sync-gdrive.sh backup
```

### Bidirectional Sync

```bash
# Keep local and Google Drive in sync
./sync-gdrive.sh sync
```

### Status Check

```bash
# See what's different between local and Google Drive
./sync-gdrive.sh status
```

## Automated Backup

### Git Hook (Auto-backup after push)

Create `.git/hooks/post-push`:

```bash
#!/bin/bash
echo "Backing up to Google Drive..."
./sync-gdrive.sh backup --force >> logs/gdrive-sync.log 2>&1
echo "Backup complete!"
```

Make it executable:

```bash
chmod +x .git/hooks/post-push
```

Now every `git push` also backs up to Google Drive!

### Cron Job (Daily backup)

```bash
# Edit crontab
crontab -e

# Add line (backup every day at 2 AM)
0 2 * * * cd /home/user/agentEther && ./sync-gdrive.sh backup --force >> logs/gdrive-sync.log 2>&1
```

## Security

### What's Protected

✅ Your `.env` file is **NEVER** synced (in `.rcloneignore`)
✅ API keys stay local only
✅ Credentials are excluded
✅ rclone.conf is not committed to git

### Google Drive Security

- Files are encrypted in transit (TLS)
- Files are encrypted at rest on Google's servers
- You control access via Google Drive permissions
- Consider enabling 2FA on your Google account

### Folder Permissions

This folder (ID: `1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo`) is:
- Owned by you
- Private by default
- Can be shared if needed

**Recommendation:** Keep it private unless you need to share with team members.

## Troubleshooting

### "Permission denied" on folder

Make sure you have access to the folder:
1. Open: https://drive.google.com/drive/folders/1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo
2. Verify you can see contents
3. Check you're logged in with correct Google account

### "Folder not found"

```bash
# Re-authenticate with correct account
rclone config reconnect agentether-gdrive:

# Or delete and recreate remote
rclone config delete agentether-gdrive
./setup-gdrive.sh
```

### Sync is slow

```bash
# Use fast-list option (caches directory listings)
rclone sync . agentether-gdrive: --fast-list --exclude-from .rcloneignore

# Or increase transfers
rclone sync . agentether-gdrive: --transfers 8 --exclude-from .rcloneignore
```

### Files not syncing

```bash
# Check what would be synced
./sync-gdrive.sh backup --dry-run --verbose

# Check exclusion rules
cat .rcloneignore

# Test specific file
rclone copy test.txt agentether-gdrive:
```

## Storage Usage

### Check Size

```bash
# Local project size
du -sh .

# Google Drive usage
rclone size agentether-gdrive:

# Detailed breakdown
./sync-gdrive.sh size
```

### Free Tier Limits

Google Drive Free Tier:
- 15 GB storage (shared with Gmail and Photos)
- Unlimited file count
- No bandwidth limits

Your agentEther project is typically:
- < 100 MB (without node_modules, logs, data)
- Well within free tier limits

## Monitoring

### View Sync Logs

```bash
# Real-time
tail -f logs/gdrive-sync.log

# Last 50 lines
tail -50 logs/gdrive-sync.log

# Search for errors
grep ERROR logs/gdrive-sync.log
```

### Last Sync Time

```bash
# Check last modified time on Google Drive
rclone lsl agentether-gdrive: | head

# Or with sync-gdrive.sh
./sync-gdrive.sh status
```

## Advanced Usage

### Sync Specific Folders

```bash
# Only environments
rclone sync environments/ agentether-gdrive:environments/ --exclude-from .rcloneignore

# Only cloudflare config
rclone sync cloudflare/ agentether-gdrive:cloudflare/ --exclude-from .rcloneignore
```

### Encrypted Backup

For extra security, use rclone crypt:

```bash
# Create encrypted remote
rclone config
# Type: crypt
# Remote: agentether-gdrive:encrypted/
# Password: <your-password>

# Sync to encrypted location
rclone sync . agentether-encrypted: --exclude-from .rcloneignore
```

### Version Control

Google Drive keeps versions automatically:
- Right-click file → "Manage versions"
- Restore previous version if needed

## Support

### Getting Help

1. Check sync status: `./sync-gdrive.sh status`
2. View logs: `tail -f logs/gdrive-sync.log`
3. Test connection: `rclone lsd agentether-gdrive:`
4. Read full guide: `cat GDRIVE-SYNC.md`

### Useful Commands

```bash
# List remotes
rclone listremotes

# Test connection
rclone lsd agentether-gdrive:

# Check config
rclone config show

# Validate folder ID
rclone lsd agentether-gdrive: --drive-root-folder-id 1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo
```

---

**Spectrum Protocol 2026** - Google Drive Folder Configuration
*Your specific folder: 1z3r8stAmWPy2ysyI8dhKjIvPMoClfEbo*
