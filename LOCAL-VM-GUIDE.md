# Local VM Development Guide

This guide explains how to deploy the microservices application to Nomad running in dev mode on an Ubuntu VM (Mac M3 host).

## 📋 Overview

This setup is optimized for:
- **Local development** on Ubuntu VM
- **Nomad dev mode** (single node)
- **Mac M3 host** (ARM64 architecture)
- **Nomad native service discovery** (no Consul required)
- **Quick iteration** and testing

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│           Mac M3 Host (ARM64)                   │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │      Ubuntu VM (ARM64)                    │ │
│  │                                           │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │   Nomad Dev Mode (dc1)              │ │ │
│  │  │                                     │ │ │
│  │  │  ┌──────────┐    ┌──────────┐     │ │ │
│  │  │  │ Backend  │    │Frontend  │     │ │ │
│  │  │  │  :3000   │◄───│  :8080   │     │ │ │
│  │  │  └──────────┘    └──────────┘     │ │ │
│  │  │       ▲               │            │ │ │
│  │  │       │               │            │ │ │
│  │  │       └───────────────┘            │ │ │
│  │  │    Nomad Service Discovery         │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  Access from Mac:                               │
│  - Frontend: http://VM_IP:8080                  │
│  - Backend:  http://VM_IP:3000                  │
│  - Nomad UI: http://VM_IP:4646                  │
└─────────────────────────────────────────────────┘
```

## 🔧 Prerequisites

### 1. Ubuntu VM Setup

**VM Requirements:**
- Ubuntu 22.04 or later
- ARM64 architecture (for Mac M3)
- 4GB+ RAM
- 20GB+ disk space
- Network bridge or NAT with port forwarding

**Installed Software:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Nomad
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=arm64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install nomad

# Verify installations
docker --version
nomad version
```

### 2. Start Nomad in Dev Mode

```bash
# Start Nomad dev mode
sudo nomad agent -dev \
  -bind 0.0.0.0 \
  -network-interface='{{ GetDefaultInterfaces | attr "name" }}'
```

**What this does:**
- `-dev`: Runs in development mode (single node, no persistence)
- `-bind 0.0.0.0`: Binds to all interfaces (accessible from Mac)
- `-network-interface`: Auto-detects the default network interface

**Verify Nomad is running:**
```bash
# In another terminal
nomad node status
nomad server members
```

### 3. Get VM IP Address

```bash
# Find VM IP address
ip addr show | grep inet
# Or
hostname -I
```

Note this IP for accessing services from your Mac.

## 🚀 Deployment

### Option 1: Using Docker Hub Images

**Step 1: Build and push images from Mac**

```bash
# On your Mac M3
cd /Users/aimeeu/Dev/github/aimeeu/microservces-app

# Build and push backend (ARM64)
docker buildx build --platform linux/arm64 \
  -t your-username/microservices-backend:latest \
  --push ./backend

# Build and push frontend (ARM64)
docker buildx build --platform linux/arm64 \
  -t your-username/microservices-frontend:latest \
  --push ./frontend
```

**Step 2: Update job file**

Edit `microservices-app-nomad-sd-localVM.nomad.hcl`:

```hcl
config {
  image = "your-username/microservices-backend:latest"
  force_pull = true  # Pull from Docker Hub
}
```

**Step 3: Deploy to Nomad**

```bash
# Copy job file to VM (from Mac)
scp microservices-app-nomad-sd-localVM.nomad.hcl user@VM_IP:~/

# SSH to VM
ssh user@VM_IP

# Deploy
nomad job run microservices-app-nomad-sd-localVM.nomad.hcl
```

### Option 2: Using Local Images (Faster for Development)

**Step 1: Build images on VM**

```bash
# On Ubuntu VM
cd ~
git clone https://github.com/your-username/microservices-app.git
cd microservices-app

# Build backend
docker build -t microservices-backend:latest ./backend

# Build frontend
docker build -t microservices-frontend:latest ./frontend

# Verify images
docker images | grep microservices
```

**Step 2: Update job file**

Edit `microservices-app-nomad-sd-localVM.nomad.hcl`:

```hcl
config {
  image = "microservices-backend:latest"  # Use local image
  force_pull = false                       # Don't pull from registry
}
```

**Step 3: Deploy**

```bash
nomad job run microservices-app-nomad-sd-localVM.nomad.hcl
```

## 🔍 Verification

### Check Job Status

```bash
# View job status
nomad job status microservices-app-local

# View allocations
nomad job allocs microservices-app-local

# Get allocation details
nomad alloc status <allocation-id>
```

### Check Service Discovery

```bash
# List registered services
nomad service list

# Get backend service info
nomad service info backend-api

# Get frontend service info
nomad service info frontend-web
```

### Test Services

```bash
# Test backend health (from VM)
curl http://localhost:3000/health

# Test backend API
curl http://localhost:3000/api/items

# Test frontend health
curl http://localhost:8080/health
```

### Access from Mac

```bash
# Replace VM_IP with your VM's IP address

# Frontend
open http://VM_IP:8080

# Backend API
curl http://VM_IP:3000/health
curl http://VM_IP:3000/api/items

# Nomad UI
open http://VM_IP:4646
```

## 📊 Monitoring

### View Logs

```bash
# Get allocation ID
ALLOC_ID=$(nomad job allocs microservices-app-local | grep backend | head -1 | awk '{print $1}')

# View backend logs
nomad alloc logs -f $ALLOC_ID backend

# View frontend logs
FRONTEND_ALLOC=$(nomad job allocs microservices-app-local | grep frontend | head -1 | awk '{print $1}')
nomad alloc logs -f $FRONTEND_ALLOC frontend
```

### Check Service Discovery

```bash
# View backend service discovery template output
nomad alloc fs $FRONTEND_ALLOC local/backend-config.env
```

Expected output:
```
BACKEND_API_HOST=172.17.0.2
BACKEND_API_PORT=3000
BACKEND_API_URL=http://172.17.0.2:3000
```

### Nomad UI

Access the Nomad UI from your Mac:
```
http://VM_IP:4646
```

Navigate to:
- **Jobs** → `microservices-app-local`
- **Services** → View registered services
- **Allocations** → View running tasks

## 🔄 Development Workflow

### Make Code Changes

```bash
# On Mac, edit code
cd /Users/aimeeu/Dev/github/aimeeu/microservces-app
# Make changes to backend/server.js or frontend/app.js
```

### Rebuild and Redeploy

**Option 1: Using Docker Hub**
```bash
# On Mac
docker buildx build --platform linux/arm64 \
  -t your-username/microservices-backend:latest \
  --push ./backend

# On VM
nomad job run microservices-app-nomad-sd-localVM.nomad.hcl
```

**Option 2: Using Local Images (Faster)**
```bash
# Copy changed files to VM
scp -r backend/ user@VM_IP:~/microservices-app/

# On VM
cd ~/microservices-app
docker build -t microservices-backend:latest ./backend
nomad job run microservices-app-nomad-sd-localVM.nomad.hcl
```

### Quick Restart

```bash
# Restart specific allocation
nomad alloc restart <allocation-id>

# Or restart entire job
nomad job restart microservices-app-local
```

## 🐛 Troubleshooting

### Issue: Can't Access Services from Mac

**Problem:** Services not accessible at `http://VM_IP:8080`

**Solutions:**

1. **Check VM networking:**
   ```bash
   # On VM
   ip addr show
   # Ensure VM has IP on accessible network
   ```

2. **Check firewall:**
   ```bash
   # On VM
   sudo ufw status
   sudo ufw allow 8080
   sudo ufw allow 3000
   sudo ufw allow 4646
   ```

3. **Verify port binding:**
   ```bash
   # On VM
   sudo netstat -tlnp | grep -E '3000|8080|4646'
   ```

### Issue: Service Discovery Not Working

**Problem:** Frontend can't find backend

**Solutions:**

1. **Check service registration:**
   ```bash
   nomad service list
   nomad service info backend-api
   ```

2. **View template output:**
   ```bash
   nomad alloc fs <frontend-alloc-id> local/backend-config.env
   ```

3. **Check backend health:**
   ```bash
   curl http://localhost:3000/health
   ```

### Issue: Docker Permission Denied

**Problem:** `permission denied while trying to connect to Docker daemon`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Verify
docker ps
```

### Issue: Nomad Can't Pull Images

**Problem:** `Failed to pull image`

**Solutions:**

1. **Use local images:**
   ```hcl
   config {
     image = "microservices-backend:latest"
     force_pull = false
   }
   ```

2. **Check Docker Hub credentials:**
   ```bash
   docker login
   ```

3. **Verify image exists:**
   ```bash
   docker pull your-username/microservices-backend:latest
   ```

## 🔧 Configuration Tips

### Adjust Resources

For limited VM resources:

```hcl
resources {
  cpu    = 250  # Reduce CPU
  memory = 128  # Reduce memory
}
```

### Enable Debug Logging

```bash
# Start Nomad with debug logging
sudo nomad agent -dev \
  -bind 0.0.0.0 \
  -network-interface='{{ GetDefaultInterfaces | attr "name" }}' \
  -log-level=DEBUG
```

### Persistent Data

Nomad dev mode doesn't persist data. For persistence:

```bash
# Create data directory
mkdir -p ~/nomad-data

# Start with data directory
sudo nomad agent -dev \
  -bind 0.0.0.0 \
  -network-interface='{{ GetDefaultInterfaces | attr "name" }}' \
  -data-dir=~/nomad-data
```

## 📝 Quick Reference

### Common Commands

```bash
# Job management
nomad job run microservices-app-nomad-sd-localVM.nomad.hcl
nomad job status microservices-app-local
nomad job stop microservices-app-local
nomad job restart microservices-app-local

# Service discovery
nomad service list
nomad service info backend-api
nomad service info frontend-web

# Allocations
nomad job allocs microservices-app-local
nomad alloc status <alloc-id>
nomad alloc logs -f <alloc-id> <task-name>
nomad alloc restart <alloc-id>

# System
nomad node status
nomad server members
```

### Access URLs

Replace `VM_IP` with your VM's IP address:

- **Frontend**: http://VM_IP:8080
- **Backend API**: http://VM_IP:3000
- **Backend Health**: http://VM_IP:3000/health
- **Nomad UI**: http://VM_IP:4646

## 🎯 Next Steps

Once comfortable with local development:

1. **Try Consul DNS**: Deploy with `microservices-app-consul-dns.nomad.hcl`
2. **Try Consul Connect**: Deploy with `microservices-app-consul.nomad.hcl`
3. **Scale up**: Increase `count` in job file
4. **Production deployment**: Use `microservices-app-nomad-sd-aws.nomad.hcl` for AWS

## 📚 Additional Resources

- [Nomad Dev Mode](https://www.nomadproject.io/docs/commands/agent#dev)
- [Nomad Service Discovery](https://www.nomadproject.io/docs/service-discovery)
- [Docker on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Nomad Templates](https://www.nomadproject.io/docs/job-specification/template)