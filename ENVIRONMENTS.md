# Multi-Environment Setup Guide

## Overview

The Spectrum Protocol 2026 supports deployment across multiple Claude Code environments. This guide explains how to work with and synchronize between environments.

## Available Environments

### 🇪🇺 SWISSAI (geminiswiss)

**Details:**
- **Location:** EU Central
- **Workspace:** geminiswiss
- **Domain:** api.geminiswiss1909.online
- **Internal DNS:** swissai.internal
- **Use Case:** EU-based deployments, data residency requirements

**Configuration:** `environments/swissai/`

### 🇺🇸 Anthropic Cloud

**Details:**
- **Location:** US East
- **Workspace:** Standard Anthropic
- **Domain:** api.geminiswiss1909.online
- **Use Case:** Standard deployments, US-based operations

**Configuration:** `environments/anthropic/`

## Environment Switching

### Method 1: Using the Switch Script (Recommended)

```bash
# Switch to SWISSAI
./switch-env.sh swissai

# Switch to Anthropic Cloud
./switch-env.sh anthropic
```

The script will:
1. ✅ Backup current configuration
2. ✅ Copy environment-specific Docker override
3. ✅ Create/update .env from template
4. ✅ Show next steps

### Method 2: Manual Switching

```bash
# 1. Backup current configuration
cp .env .env.backup
cp docker-compose.override.yml docker-compose.override.backup.yml

# 2. Copy environment configuration
cp environments/swissai/docker-compose.override.yml .
cp environments/swissai/.env.template .env

# 3. Edit credentials
nano .env

# 4. Verify
docker-compose config
```

## Synchronization Workflows

### Scenario 1: Develop in SWISSAI, Deploy to Anthropic Cloud

**In SWISSAI environment:**

```bash
# 1. Make your changes
# ... edit files ...

# 2. Test locally
./switch-env.sh swissai
docker-compose up -d
docker-compose logs -f

# 3. Commit and push
git add .
git commit -m "Add new feature"
git push origin claude/fix-kernel-stability-1oIFj
```

**Switch to Anthropic Cloud environment in Claude Code:**
1. Click environment selector in Claude Code
2. Choose: **anthropic cloud**

**In Anthropic Cloud environment:**

```bash
# 1. Pull latest changes
git pull origin claude/fix-kernel-stability-1oIFj

# 2. Switch environment configuration
./switch-env.sh anthropic

# 3. Update credentials if needed
nano .env

# 4. Deploy
docker-compose up -d
```

### Scenario 2: Synchronize Both Environments

```bash
# Keep both environments in sync by using the same branch
# Always pull before making changes

git pull origin claude/fix-kernel-stability-1oIFj

# After making changes, push immediately
git push origin claude/fix-kernel-stability-1oIFj
```

### Scenario 3: Environment-Specific Changes

For changes that should only apply to one environment:

```bash
# Create environment-specific branch
git checkout -b swissai/custom-feature

# Make environment-specific changes in environments/swissai/
# Edit environments/swissai/docker-compose.override.yml

git add environments/swissai/
git commit -m "SWISSAI: Add custom feature"
git push origin swissai/custom-feature
```

## Working Across Multiple Claude Code Windows

You can have both environments open simultaneously:

### Window 1: SWISSAI
```bash
# Terminal 1 - SWISSAI environment
export PS1="[SWISSAI] \w $ "
./switch-env.sh swissai
docker-compose up -d
```

### Window 2: Anthropic Cloud
```bash
# Terminal 2 - Anthropic Cloud environment
export PS1="[ANTHROPIC] \w $ "
./switch-env.sh anthropic
docker-compose up -d
```

⚠️ **Warning:** Make sure they use different ports or Docker networks to avoid conflicts!

## Configuration Files Explained

### 1. Base Configuration (Applied to All Environments)

**File:** `docker-compose.yml`
- Base service definitions
- Common environment variables
- Shared volumes and networks

### 2. Environment Overrides (Environment-Specific)

**Files:** `environments/<env>/docker-compose.override.yml`
- Environment-specific settings
- Resource limits
- Custom environment variables

Docker Compose automatically merges these files when you run `docker-compose up`.

### 3. Environment Templates

**Files:** `environments/<env>/.env.template`
- Template for environment-specific credentials
- Includes placeholders for API keys
- Documents required variables

## Best Practices

### ✅ DO:

1. **Always use the switch script** when changing environments
   ```bash
   ./switch-env.sh <environment>
   ```

2. **Commit shared changes to the main branch**
   ```bash
   git push origin claude/fix-kernel-stability-1oIFj
   ```

3. **Document environment-specific requirements** in `environments/<env>/README.md`

4. **Test in one environment before deploying to others**

5. **Keep .env files separate** (never commit them!)

### ❌ DON'T:

1. **Don't commit .env files** (they contain secrets!)
   - ✅ Commit: `.env.template`, `.env.example`
   - ❌ Don't commit: `.env`, `.env.local`

2. **Don't mix environment configurations**
   - Always use the switch script
   - Don't manually edit docker-compose.override.yml

3. **Don't hardcode environment-specific values** in base docker-compose.yml
   - Use environment variables
   - Use overrides for environment-specific settings

## Troubleshooting

### Issue: "Environment mismatch"

**Symptoms:** Services start but use wrong configuration

**Solution:**
```bash
# Verify current environment
docker-compose config | grep ENVIRONMENT

# Re-apply environment configuration
./switch-env.sh <correct-environment>
docker-compose down
docker-compose up -d
```

### Issue: "Configuration conflicts"

**Symptoms:** Docker Compose shows warnings about duplicate keys

**Solution:**
```bash
# Check for conflicts
docker-compose config

# Verify override file is correct
cat docker-compose.override.yml

# Re-apply environment
./switch-env.sh <environment>
```

### Issue: "Can't switch environments"

**Symptoms:** Switch script fails or shows errors

**Solution:**
```bash
# Make script executable
chmod +x switch-env.sh

# Check environment directory exists
ls -la environments/

# Run with verbose output
bash -x switch-env.sh <environment>
```

## Environment Variable Reference

### Common Variables (All Environments)

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Gemini API key | Yes |
| `CLAUDE_API_KEY` | Claude API key | Yes |
| `NODE_ENV` | Node environment | Yes |
| `MCP_PORT` | MCP gateway port | Yes |
| `SOCKET_MCP_PORT` | Socket.io port | Yes |

### Environment-Specific Variables

#### SWISSAI
| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment identifier | `swissai` |
| `CLOUDFLARE_TOKEN_SWISSAI` | SWISSAI Cloudflare token | Required |
| `WORKSPACE_ID` | Workspace identifier | `swissai-geminiswiss` |
| `DEPLOYMENT_REGION` | Deployment region | `eu-central` |
| `ALLOWED_HOSTS` | Allowed hostnames | Includes `swissai.internal` |

#### Anthropic Cloud
| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment identifier | `anthropic` |
| `CLOUDFLARE_TOKEN_ANTHROPIC` | Anthropic Cloudflare token | Required |
| `WORKSPACE_ID` | Workspace identifier | `anthropic-cloud` |
| `DEPLOYMENT_REGION` | Deployment region | `us-east` |

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Multi-Environment Deployment

on:
  push:
    branches:
      - claude/fix-kernel-stability-1oIFj

jobs:
  deploy-swissai:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to SWISSAI
        run: |
          ./switch-env.sh swissai
          # Add deployment commands

  deploy-anthropic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Anthropic Cloud
        run: |
          ./switch-env.sh anthropic
          # Add deployment commands
```

## Support

For environment-specific support:

- **SWISSAI:** See `environments/swissai/README.md`
- **Anthropic Cloud:** See `environments/anthropic/README.md`
- **General issues:** Open GitHub issue

## Contributing

When adding a new environment:

1. Create directory: `environments/<new-env>/`
2. Add `docker-compose.override.yml`
3. Add `.env.template`
4. Add `README.md`
5. Update this document
6. Update `switch-env.sh` with new environment option

---

**Last Updated:** 2026-01-13
**Version:** 1.0.0
**Spectrum Protocol:** 2026
