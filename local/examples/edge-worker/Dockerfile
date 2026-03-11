FROM node:20-alpine

WORKDIR /app

# Install build dependencies for better-sqlite3
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy application files
COPY local-worker.js ./
COPY agent_core.wasm ./

# Create data directory
RUN mkdir -p /app/data && chown -R node:node /app/data
USER node

EXPOSE 8787

CMD ["npm", "start"]
