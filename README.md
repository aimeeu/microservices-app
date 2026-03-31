# Multi-Architecture Microservices Application

A basic microservices application demonstrating frontend and backend separation
with support for both **ARM64** and **AMD64** architectures.

IBM Bob generated this code.

## 🏗️ Architecture

```
┌─────────────────┐         ┌─────────────────┐
│                 │         │                 │
│    Frontend     │────────▶│     Backend     │
│  (Nginx/HTML)   │  HTTP   │   (Node.js)     │
│   Port: 8080    │         │   Port: 3000    │
│                 │         │                 │
└─────────────────┘         └─────────────────┘
```

## 📦 Components

### Backend Service
- **Technology**: Node.js with Express
- **Port**: 3000
- **Features**:
  - RESTful API for CRUD operations
  - Health check endpoint
  - CORS enabled
  - Architecture detection

### Frontend Service
- **Technology**: HTML, CSS, JavaScript with Nginx
- **Port**: 8080
- **Features**:
  - Modern responsive UI
  - Real-time item management
  - Backend status monitoring
  - Auto-refresh capabilities

## 🎯 Deployment Options

This application supports multiple deployment strategies:

1. **Docker Compose** - Local development and testing
2. **Nomad (Basic)** - Simple production deployment
3. **Nomad + Consul DNS** - Service discovery without service mesh (see [CONSUL-DNS-GUIDE.md](CONSUL-DNS-GUIDE.md))
4. **Nomad + Consul Connect** - Full service mesh with mTLS

### Quick Nomad Deployment

```bash
# Basic Nomad deployment
nomad job run microservices-app.nomad.hcl

# With Consul DNS service discovery
nomad job run microservices-app-consul-dns.nomad.hcl

# With Consul Connect service mesh
nomad job run microservices-app-consul.nomad.hcl
```

**Deployment Guides:**
- [Nomad Deployment Guide](NOMAD-DEPLOYMENT.md) - Comprehensive Nomad deployment instructions
- [Consul DNS Guide](CONSUL-DNS-GUIDE.md) - Using Consul DNS for service discovery


## 🚀 Quick Start

### Prerequisites
- Docker installed
- Docker Compose installed (optional, for easier deployment)
- HashiCorp Nomad (optional, for production deployment)

### Option 1: Using Docker Compose (Recommended)

```bash
# Navigate to the project directory
cd microservices-app

# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

Access the application:
- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:3000
- **Backend Health**: http://localhost:3000/health

### Option 2: Using Docker Commands

#### Build Images

```bash
# Build backend image
docker build -t microservices-backend:latest ./backend

# Build frontend image
docker build -t microservices-frontend:latest ./frontend
```

#### Run Containers

```bash
# Create a network
docker network create microservices-network

# Run backend
docker run -d \
  --name backend \
  --network microservices-network \
  -p 3000:3000 \
  microservices-backend:latest

# Run frontend
docker run -d \
  --name frontend \
  --network microservices-network \
  -p 8080:80 \
  microservices-frontend:latest
```

## 🏗️ Building Multi-Architecture Images

To build images that work on both ARM64 and AMD64:

### Setup Docker Buildx

```bash
# Create a new builder instance
docker buildx create --name multiarch --use

# Verify the builder
docker buildx inspect --bootstrap
```

### Build Multi-Arch Images

```bash
# Build and push backend (replace with your registry)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/microservices-backend:latest \
  --push \
  ./backend

# Build and push frontend (replace with your registry)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/microservices-frontend:latest \
  --push \
  ./frontend
```

## 📡 API Endpoints

### Backend API

#### Health Check
```
GET /health
```
Returns backend status and system information.

#### Get All Items
```
GET /api/items
```
Returns all items in the system.

#### Get Single Item
```
GET /api/items/:id
```
Returns a specific item by ID.

#### Create Item
```
POST /api/items
Content-Type: application/json

{
  "name": "Item Name",
  "description": "Item Description"
}
```

#### Update Item
```
PUT /api/items/:id
Content-Type: application/json

{
  "name": "Updated Name",
  "description": "Updated Description"
}
```

#### Delete Item
```
DELETE /api/items/:id
```

## 🧪 Testing

### Test Backend Directly

```bash
# Health check
curl http://localhost:3000/health

# Get all items
curl http://localhost:3000/api/items

# Create an item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Test Description"}'

# Delete an item
curl -X DELETE http://localhost:3000/api/items/1
```

### Test Frontend

Open your browser and navigate to:
```
http://localhost:8080
```

## 🔍 Monitoring

### View Container Logs

```bash
# Using Docker Compose
docker-compose logs -f backend
docker-compose logs -f frontend

# Using Docker
docker logs -f backend
docker logs -f frontend
```

### Check Container Health

```bash
# Using Docker Compose
docker-compose ps

# Using Docker
docker ps
```

## 🛠️ Development

### Backend Development

```bash
cd backend

# Install dependencies
npm install

# Run in development mode
npm run dev
```

### Frontend Development

For frontend development, you can use any local web server:

```bash
cd frontend

# Using Python
python3 -m http.server 8080

# Using Node.js http-server
npx http-server -p 8080
```

## 📁 Project Structure

```
microservices-app/
├── backend/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   └── server.js
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── index.html
│   ├── styles.css
│   └── app.js
├── docker-compose.yml
└── README.md
```

## 🔧 Configuration

### Backend Environment Variables

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment mode (default: production)

### Frontend Configuration

The frontend automatically detects the backend URL:
- **Localhost**: Uses `http://localhost:3000`
- **Docker**: Uses `http://backend:3000`

## 🐛 Troubleshooting

### Backend not accessible from frontend

Ensure both containers are on the same network:
```bash
docker network inspect microservices-network
```

### Port already in use

Change the port mapping in `docker-compose.yml`:
```yaml
ports:
  - "8081:80"  # Change 8080 to 8081
```

### Architecture mismatch

Verify your system architecture:
```bash
docker version | grep Arch
```

Build for your specific architecture:
```bash
docker build --platform linux/arm64 -t backend:latest ./backend
```

## 📝 License

MIT License - feel free to use this project for learning and development.

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Node.js Documentation](https://nodejs.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🎯 Deployment Options

This application can be deployed in multiple ways:

1. **Docker Compose** - Local development and testing
2. **HashiCorp Nomad** - Production orchestration (see [NOMAD-DEPLOYMENT.md](NOMAD-DEPLOYMENT.md))
3. **Kubernetes** - Alternative orchestration platform

### Nomad Deployment

For production deployment using HashiCorp Nomad, see the comprehensive [Nomad Deployment Guide](NOMAD-DEPLOYMENT.md).

Quick Nomad deployment:

```bash
# Update the Docker Hub username in the job file
# Then deploy:
nomad job run microservices-app.nomad.hcl

# Or with Consul service discovery:
nomad job run microservices-app-consul.nomad.hcl
```

**Nomad Features:**
- Multi-architecture support (ARM64/AMD64)
- High availability with multiple replicas
- Rolling updates with auto-revert
- Health checks and monitoring
- Optional Consul Connect service mesh
