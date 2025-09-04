# Multi-stage build for AnimaGenius API
FROM node:18-alpine AS base

# Install system dependencies and security updates
RUN apk update && apk upgrade && \
    apk add --no-cache \
    dumb-init \
    curl \
    tzdata && \
    rm -rf /var/cache/apk/*

# Create app user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

FROM base AS deps
# Install dependencies
RUN npm ci --only=production --no-audit --no-fund && \
    npm cache clean --force

FROM base AS build
# Install all dependencies (including dev)
RUN npm ci --no-audit --no-fund

# Copy source code
COPY src ./src
COPY prisma ./prisma

# Build application
RUN npm run build && \
    npm run prisma:generate

FROM base AS runtime
# Copy dependencies from deps stage
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Copy built application
COPY --from=build --chown=nodeuser:nodejs /app/dist ./dist
COPY --from=build --chown=nodeuser:nodejs /app/prisma ./prisma
COPY --from=build --chown=nodeuser:nodejs /app/node_modules/.prisma ./node_modules/.prisma

# Copy package.json for runtime
COPY --chown=nodeuser:nodejs package.json ./

# Create necessary directories
RUN mkdir -p /app/tmp /app/logs /app/uploads && \
    chown -R nodeuser:nodejs /app/tmp /app/logs /app/uploads

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Switch to non-root user
USER nodeuser

# Expose port
EXPOSE 3000

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "dist/server.js"]

# Labels
LABEL \
    org.opencontainers.image.title="AnimaGenius API" \
    org.opencontainers.image.description="AnimaGenius API Server" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.vendor="AnimaGenius" \
    maintainer="dev@animagenius.com"