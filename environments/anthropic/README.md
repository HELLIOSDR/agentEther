# Anthropic Cloud Environment Configuration

## Overview

This directory contains configuration specific to the **Anthropic Cloud** Claude Code environment.

## Environment Details

- **Name:** Anthropic Cloud
- **Type:** Claude Code Workspace
- **Region:** US East
- **Domain:** api.geminiswiss1909.online
- **Workspace ID:** anthropic-cloud

## Quick Start

### 1. Switch to Anthropic Cloud Environment

From the project root:

```bash
./switch-env.sh anthropic
```

### 2. Configure Credentials

Edit the `.env` file created in the project root:

```bash
nano .env
```

Required variables:
- `GEMINI_API_KEY` - Your Anthropic Cloud Gemini API key
- `CLAUDE_API_KEY` - Your Anthropic Cloud Claude API key
- `CLOUDFLARE_TOKEN_ANTHROPIC` - Your Anthropic Cloud Cloudflare tunnel token

### 3. Verify Configuration

```bash
docker-compose config
```

### 4. Deploy

```bash
docker-compose up -d
```

## Anthropic Cloud-Specific Features

### Standard Configuration
- US-based deployment
- Standard ALLOWED_HOSTS configuration
- Production-grade resource allocation

### Resource Allocation
- Reserved: 1 CPU, 2GB RAM
- Limits: 2 CPUs, 4GB RAM

### Network Configuration
- Standard service discovery
- Cloudflare tunnel with US routing

## Monitoring

Check service status:
```bash
docker-compose ps
docker-compose logs -f mcp-gateway
```

Health endpoint:
```bash
curl http://localhost:3000/health
```

## Troubleshooting

### Issue: Can't connect to Anthropic Cloud workspace

**Solution:** Ensure you're in the Anthropic Cloud Claude Code environment:
1. Open Claude Code
2. Select environment: **anthropic cloud**
3. Re-run deployment

### Issue: Cloudflare tunnel fails

**Solution:** Verify `CLOUDFLARE_TOKEN_ANTHROPIC` is correct:
```bash
grep CLOUDFLARE_TOKEN_ANTHROPIC .env
```

## Files in This Directory

- `docker-compose.override.yml` - Anthropic Cloud-specific Docker overrides
- `.env.template` - Environment variable template for Anthropic Cloud
- `README.md` - This file

## Synchronization

To sync from SWISSAI to Anthropic Cloud:

```bash
# In SWISSAI environment, commit and push changes
git push origin claude/fix-kernel-stability-1oIFj

# Switch to Anthropic Cloud environment
# Select: anthropic cloud in Claude Code environment picker
# Pull latest changes
git pull origin claude/fix-kernel-stability-1oIFj

# Apply Anthropic Cloud configuration
./switch-env.sh anthropic
```

## Support

For Anthropic Cloud-specific issues:
- Check logs: `docker-compose logs`
- Verify environment: `echo $ENVIRONMENT` (should show "anthropic")
- Visit: https://console.anthropic.com
