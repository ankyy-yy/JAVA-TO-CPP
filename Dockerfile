FROM node:20-bookworm

WORKDIR /app

# Install required tools
RUN apt-get update && apt-get install -y \
    flex \
    bison \
    gcc \
    g++ \
    default-jdk \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# Install Node dependencies
RUN npm install

# Copy full project
COPY . .

# Build transpiler
RUN make

# Expose port
EXPOSE 3000

# Start server
CMD ["node", "server.js"]