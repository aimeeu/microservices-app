# Nomad Deployment Guide

This guide explains how to deploy the microservices application to HashiCorp Nomad.

## 📋 Prerequisites

- HashiCorp Nomad cluster running
- Docker driver enabled on Nomad clients
- (Optional) Consul for service discovery
- Docker images pushed to Docker Hub

## 🐳 Push Images to Docker Hub

Before deploying to Nomad, you need to push your images to Docker Hub:

### 1. Build Multi-Architecture Images

```bash
# Login to Docker Hub
docker login

# Create buildx builder
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Build and push backend
cd backend
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-dockerhub-username/microservices-backend:latest \
  --push \
  .

# Build and push frontend
cd ../frontend
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-dockerhub-username/microservices-frontend:latest \
  --push \
  .
```

### 2. Update Nomad Job Files

Edit the Nomad job files and replace `your-dockerhub-username` with your actual Docker Hub username:

- `microservices-app.nomad.hcl`
- `microservices-app-consul.nomad.hcl`

## 🚀 Deployment Options

### Option 1: Basic Nomad Deployment (No Consul)

This deployment uses basic Nomad service discovery.

```bash
# Validate the job file
nomad job validate microservices-app.nomad.hcl

# Plan the deployment (dry run)
nomad job plan microservices-app.nomad.hcl

# Run the job
nomad job run microservices-app.nomad.hcl

# Check job status
nomad job status microservices-app

# View allocations
nomad job allocs microservices-app
```

**Access the application:**
- Frontend: `http://<nomad-client-ip>:8080`
- Backend: `http://<nomad-client-ip>:<dynamic-port>`

### Option 2: Consul Service Discovery

This deployment uses Consul Connect for service mesh and service discovery.

**Prerequisites:**
- Consul agent running on Nomad clients
- Consul Connect enabled

```bash
# Validate the job file
nomad job validate microservices-app-consul.nomad.hcl

# Plan the deployment
nomad job plan microservices-app-consul.nomad.hcl

# Run the job
nomad job run microservices-app-consul.nomad.hcl

# Check job status
nomad job status microservices-app-consul

# View services in Consul
consul catalog services
```

**Access the application:**
- Frontend: `http://<nomad-client-ip>:8080`
- Backend is accessed via Consul Connect sidecar proxy

## 📊 Monitoring and Management

### View Job Status

```bash
# Overall job status
nomad job status microservices-app

# Detailed allocation information
nomad alloc status <allocation-id>

# View logs
nomad alloc logs <allocation-id> backend
nomad alloc logs <allocation-id> frontend
```

### View Service Health

```bash
# Using Nomad
nomad service list

# Using Consul (if enabled)
consul catalog services
consul health service backend-api
consul health service frontend-web
```

### Scale Services

```bash
# Edit the job file and change the count
# Then run:
nomad job run microservices-app.nomad.hcl
```

Or use the Nomad UI to scale services.

## 🔄 Updates and Rollbacks

### Update Application

```bash
# After pushing new images to Docker Hub
nomad job run microservices-app.nomad.hcl

# Monitor the update
nomad job status microservices-app
```

### Rollback

```bash
# View job versions
nomad job history microservices-app

# Revert to previous version
nomad job revert microservices-app <version-number>
```

## 🐛 Troubleshooting

### Check Allocation Status

```bash
# List all allocations
nomad job allocs microservices-app

# Check specific allocation
nomad alloc status <allocation-id>

# View allocation logs
nomad alloc logs -f <allocation-id> backend
```

### Common Issues

#### 1. Image Pull Failures

**Problem:** Nomad can't pull the Docker image

**Solution:**
- Verify image exists on Docker Hub: `docker pull your-dockerhub-username/microservices-backend:latest`
- Check Docker Hub credentials on Nomad clients
- Ensure the image supports the node's architecture (ARM64 or AMD64)

#### 2. Port Conflicts

**Problem:** Port 8080 already in use

**Solution:**
- Change the static port in the job file:
```hcl
port "http" {
  static = 8081  # Change to available port
  to     = 80
}
```

#### 3. Service Not Healthy

**Problem:** Health checks failing

**Solution:**
- Check allocation logs: `nomad alloc logs <allocation-id>`
- Verify the health check endpoint is accessible
- Increase `healthy_deadline` in the job file

#### 4. Backend Not Accessible from Frontend

**Problem:** Frontend can't connect to backend

**Solution:**

For basic deployment:
- Use Nomad service discovery
- Update frontend to use service name instead of localhost

For Consul deployment:
- Verify Consul Connect is working
- Check sidecar proxy logs
- Ensure upstream configuration is correct

### View Nomad Client Logs

```bash
# On the Nomad client node
journalctl -u nomad -f
```

## 🔧 Configuration

### Job Configuration Options

#### Resource Allocation

Adjust resources in the job file:

```hcl
resources {
  cpu    = 500   # MHz
  memory = 256   # MB
}
```

#### Replica Count

Change the number of instances:

```hcl
group "backend" {
  count = 3  # Run 3 instances
  # ...
}
```

#### Update Strategy

Configure rolling updates:

```hcl
update {
  max_parallel     = 1      # Update 1 at a time
  min_healthy_time = "10s"  # Wait 10s before next
  healthy_deadline = "3m"   # Fail after 3 minutes
  auto_revert      = true   # Rollback on failure
}
```

## 📈 Production Considerations

### 1. High Availability

- Run multiple instances of each service (count > 1)
- Spread across multiple Nomad clients
- Use Consul for service discovery

### 2. Resource Limits

- Set appropriate CPU and memory limits
- Monitor resource usage
- Adjust based on load

### 3. Health Checks

- Configure appropriate intervals
- Set realistic timeouts
- Monitor health check failures

### 4. Logging

- Configure log rotation
- Use centralized logging (e.g., ELK stack)
- Monitor application logs

### 5. Security

- Use Consul Connect for encrypted service-to-service communication
- Implement network policies
- Use secrets management (Vault)
- Keep images updated

## 🔗 Useful Commands

```bash
# Job management
nomad job status microservices-app
nomad job stop microservices-app
nomad job restart microservices-app

# Allocation management
nomad alloc status <alloc-id>
nomad alloc logs <alloc-id> <task-name>
nomad alloc restart <alloc-id>

# Service discovery
nomad service list
nomad service info backend-api

# System status
nomad node status
nomad server members
```

## 📚 Additional Resources

- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Nomad Docker Driver](https://www.nomadproject.io/docs/drivers/docker)
- [Consul Connect](https://www.consul.io/docs/connect)
- [Nomad Service Discovery](https://www.nomadproject.io/docs/service-discovery)