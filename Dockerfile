# Spectrum Protocol 2026 - MCP Gateway Container
# Multi-stage build for optimized image size

FROM node:20-slim AS base

# Install system dependencies and security tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    net-tools \
    iproute2 \
    iptables \
    nmap \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files (placeholder - adjust based on actual project structure)
# COPY package*.json ./

# Install Node.js dependencies (placeholder)
# RUN npm ci --only=production

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /app/data /app/config /app/chromadb

# Set permissions
RUN chmod -R 755 /app

# Expose ports
EXPOSE 3000 3001

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD curl -f http://localhost:3000/health || exit 1

# Default environment variables
ENV NODE_ENV=production \
    MCP_PORT=3000 \
    SOCKET_MCP_PORT=3001 \
    LOG_LEVEL=info

# Start command (placeholder - adjust based on actual application)
CMD ["node", "index.js"]
