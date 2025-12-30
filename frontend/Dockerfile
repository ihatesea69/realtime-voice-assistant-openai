# Frontend Dockerfile - Development mode for WSL2
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 5173

# Run dev server with host binding for external access
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
