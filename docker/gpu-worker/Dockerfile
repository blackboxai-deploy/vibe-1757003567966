# Multi-stage build for AnimaGenius GPU Worker
FROM nvidia/cuda:11.8-devel-ubuntu20.04 AS base

# Install system dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-dev \
    ffmpeg \
    imagemagick \
    git \
    build-essential \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install Python packages for AI/ML
RUN pip3 install --no-cache-dir \
    torch==2.0.1+cu118 \
    torchvision==0.15.2+cu118 \
    torchaudio==2.0.2+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

RUN pip3 install --no-cache-dir \
    transformers==4.30.2 \
    diffusers==0.18.2 \
    accelerate==0.20.3 \
    xformers==0.0.20 \
    opencv-python==4.8.0.74 \
    pillow==10.0.0 \
    numpy==1.24.3 \
    scipy==1.11.1

# Create app user
RUN useradd --create-home --shell /bin/bash --uid 1001 nodeuser

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
COPY models ./models

# Build application
RUN npm run build && \
    npm run prisma:generate

FROM base AS runtime
# Copy dependencies from deps stage
COPY --from=deps --chown=nodeuser:nodeuser /app/node_modules ./node_modules

# Copy built application
COPY --from=build --chown=nodeuser:nodeuser /app/dist ./dist
COPY --from=build --chown=nodeuser:nodeuser /app/prisma ./prisma
COPY --from=build --chown=nodeuser:nodeuser /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build --chown=nodeuser:nodeuser /app/models ./models

# Copy package.json for runtime
COPY --chown=nodeuser:nodeuser package.json ./

# Create necessary directories with extra space for model cache
RUN mkdir -p /app/tmp /app/logs /app/processing /app/models-cache /app/output && \
    chown -R nodeuser:nodeuser /app/tmp /app/logs /app/processing /app/models-cache /app/output

# Pre-download common models (optional)
USER nodeuser
RUN python3 -c "
import torch
from transformers import pipeline
from diffusers import DiffusionPipeline
print('Pre-caching models...')
# Cache a lightweight model for faster startup
try:
    pipe = pipeline('text-classification', model='distilbert-base-uncased-finetuned-sst-2-english')
    print('Text classification model cached')
except:
    print('Skipping text model cache')
print('Model caching complete')
"

# Health check
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3002/health || exit 1

# Expose port
EXPOSE 3002

# Set environment
ENV NODE_ENV=production
ENV PORT=3002
ENV WORKER_TYPE=gpu
ENV CUDA_VISIBLE_DEVICES=0
ENV PYTHONPATH=/app/models

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start GPU worker
CMD ["node", "dist/gpu-worker.js"]

# Labels
LABEL \
    org.opencontainers.image.title="AnimaGenius GPU Worker" \
    org.opencontainers.image.description="AnimaGenius GPU-Accelerated Worker" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.vendor="AnimaGenius" \
    maintainer="dev@animagenius.com"