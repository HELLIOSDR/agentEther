# SWISSAI Environment Configuration

## Overview

This directory contains configuration specific to the **SWISSAI/geminiswiss** Claude Code environment.

## Environment Details

- **Name:** SWISSAI
- **Type:** Claude Code Workspace
- **Region:** EU Central
- **Domain:** api.geminiswiss1909.online
- **Workspace ID:** swissai-geminiswiss

## Quick Start

### 1. Switch to SWISSAI Environment

From the project root:

```bash
./switch-env.sh swissai
```

### 2. Configure Credentials

Edit the `.env` file created in the project root:

```bash
nano .env
```

Required variables:
- `GEMINI_API_KEY` - Your SWISSAI Gemini API key
- `CLAUDE_API_KEY` - Your SWISSAI Claude API key
- `CLOUDFLARE_TOKEN_SWISSAI` - Your SWISSAI Cloudflare tunnel token

### 3. Verify Configuration

```bash
docker-compose config
```

### 4. Deploy

```bash
docker-compose up -d
```

## SWISSAI-Specific Features

### Enhanced Security
- Additional internal host: `swissai.internal`
- EU data residency compliance
- Enhanced audit logging

### Resource Allocation
- Reserved: 1 CPU, 2GB RAM
- Limits: 2 CPUs, 4GB RAM

### Network Configuration
- Internal service discovery via `swissai.internal`
- Cloudflare tunnel with EU routing

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

### Issue: Can't connect to SWISSAI workspace

**Solution:** Ensure you're in the SWISSAI Claude Code environment:
1. Open Claude Code
2. Select environment: **SWISSAI**
3. Re-run deployment

### Issue: Cloudflare tunnel fails

**Solution:** Verify `CLOUDFLARE_TOKEN_SWISSAI` is correct:
```bash
grep CLOUDFLARE_TOKEN_SWISSAI .env
```

## Files in This Directory

- `docker-compose.override.yml` - SWISSAI-specific Docker overrides
- `.env.template` - Environment variable template for SWISSAI
- `README.md` - This file

## Synchronization

To sync from Anthropic Cloud to SWISSAI:

```bash
# In Anthropic Cloud environment, commit and push changes
git push origin claude/fix-kernel-stability-1oIFj

# Switch to SWISSAI environment
# Select: SWISSAI in Claude Code environment picker
# Pull latest changes
git pull origin claude/fix-kernel-stability-1oIFj

# Apply SWISSAI configuration
./switch-env.sh swissai
```

## Support

For SWISSAI-specific issues:
- Check logs: `docker-compose logs`
- Verify environment: `echo $ENVIRONMENT` (should show "swissai")
- Contact: workspace administrator
