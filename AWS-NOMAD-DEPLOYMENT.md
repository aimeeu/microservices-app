# AWS Multi-Node Nomad Deployment Guide

This guide explains how to deploy the microservices application on a multi-node Nomad cluster running on AWS using Nomad native service discovery.

## 📋 Overview

This deployment uses:
- **Nomad Native Service Discovery** - Built-in service registry (no Consul required)
- **Multi-Node Cluster** - Distributed across AWS availability zones
- **High Availability** - Multiple instances with automatic failover
- **Zero-Downtime Deployments** - Canary deployments with auto-rollback
- **AWS Optimization** - Support for both AMD64 and ARM64 (Graviton) instances

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Region (us-east-1)                   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   AZ-1a      │  │   AZ-1b      │  │   AZ-1c      │    │
│  │              │  │              │  │              │    │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │    │
│  │ │ Backend  │ │  │ │ Backend  │ │  │ │ Backend  │ │    │
│  │ │ Instance │ │  │ │ Instance │ │  │ │ Instance │ │    │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │    │
│  │              │  │              │  │              │    │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │    │
│  │ │Frontend  │ │  │ │Frontend  │ │  │ │Frontend  │ │    │
│  │ │ Instance │ │  │ │ Instance │ │  │ │ Instance │ │    │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │         Nomad Native Service Discovery              │  │
│  │  - backend-api: 3 instances across AZs              │  │
│  │  - frontend-web: 3 instances across AZs             │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Application Load Balancer              │  │
│  │         (Routes traffic to frontend:8080)           │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Prerequisites

### 1. AWS Infrastructure

**Nomad Cluster:**
- 3+ Nomad server nodes (for quorum)
- 3+ Nomad client nodes (across multiple AZs)
- VPC with subnets in multiple availability zones
- Security groups configured for Nomad communication

**Instance Types:**
- AMD64: `t3.medium`, `t3.large`, `m5.large`
- ARM64 (Graviton): `t4g.medium`, `t4g.large`, `m6g.large`

**Networking:**
- VPC with public/private subnets
- Internet Gateway or NAT Gateway
- Application Load Balancer (optional)

### 2. Nomad Configuration

Ensure Nomad clients have:
- Docker driver enabled
- Host networking mode available
- Sufficient resources allocated

### 3. Docker Images

Push multi-architecture images to Docker Hub:

```bash
# Build and push backend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-username/microservices-backend:latest \
  --push ./backend

# Build and push frontend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-username/microservices-frontend:latest \
  --push ./frontend
```

## 🚀 Deployment

### Step 1: Configure Datacenters

Edit `microservices-app-nomad-sd-aws.nomad.hcl` to match your AWS setup:

```hcl
datacenters = ["us-east-1a", "us-east-1b", "us-east-1c"]
```

Replace with your actual availability zones.

### Step 2: Update Docker Hub Username

```hcl
config {
  image = "your-dockerhub-username/microservices-backend:latest"
}
```

### Step 3: Validate the Job

```bash
nomad job validate microservices-app-nomad-sd-aws.nomad.hcl
```

### Step 4: Plan the Deployment

```bash
nomad job plan microservices-app-nomad-sd-aws.nomad.hcl
```

Review the output to see:
- Which nodes will run allocations
- Resource requirements
- Service registrations

### Step 5: Run the Job

```bash
nomad job run microservices-app-nomad-sd-aws.nomad.hcl
```

### Step 6: Monitor Deployment

```bash
# Watch job status
watch nomad job status microservices-app-nomad-sd-aws

# View allocations
nomad job allocs microservices-app-nomad-sd-aws

# Check service health
nomad service list
nomad service info backend-api
nomad service info frontend-web
```

## 🔍 Nomad Native Service Discovery

### How It Works

Nomad maintains an internal service registry:

1. **Service Registration**: When a task starts, Nomad registers it
2. **Health Checking**: Nomad monitors service health
3. **Service Queries**: Other services query Nomad for healthy instances
4. **Dynamic Updates**: Registry updates automatically as services scale

### Service Registration

Backend service registers automatically:

```hcl
service {
  name = "backend-api"
  port = "http"
  
  tags = ["backend", "api", "aws"]
  
  meta {
    version = "1.0.0"
    region  = "${node.datacenter}"
  }
  
  check {
    type     = "http"
    path     = "/health"
    interval = "10s"
    timeout  = "2s"
  }
}
```

### Service Discovery in Frontend

Frontend discovers backend using Nomad templates:

```hcl
template {
  data = <<EOH
{{- range nomadService "backend-api" }}
  {{- if .Healthy }}
BACKEND_API_URL=http://{{ .Address }}:{{ .Port }}
  {{- end }}
{{- end }}
EOH
  destination = "local/backend-config.env"
  env         = true
  change_mode = "restart"
}
```

### Query Services

```bash
# List all services
nomad service list

# Get service details
nomad service info backend-api

# Query with tags
nomad service info -tag aws backend-api

# JSON output for automation
nomad service info -json backend-api
```

## 🌐 AWS-Specific Features

### 1. Multi-AZ Deployment

Services spread across availability zones:

```hcl
spread {
  attribute = "${node.datacenter}"
  weight    = 100
}
```

### 2. Distinct Hosts

Prevent multiple instances on same node:

```hcl
constraint {
  operator = "distinct_hosts"
  value    = "true"
}
```

### 3. Instance Metadata

Access AWS instance information:

```hcl
env {
  AWS_REGION    = "${node.datacenter}"
  INSTANCE_ID   = "${node.unique.name}"
  ALLOCATION_ID = "${NOMAD_ALLOC_ID}"
}
```

### 4. Graviton Support

Automatically works on ARM64 (Graviton) instances:

```hcl
constraint {
  operator = "regexp"
  attribute = "${attr.cpu.arch}"
  value     = "amd64|arm64"
}
```

## 🔄 High Availability Features

### 1. Multiple Replicas

```hcl
group "backend" {
  count = 3  # 3 backend instances
}

group "frontend" {
  count = 3  # 3 frontend instances
}
```

### 2. Health Checks

Automatic health monitoring:

```hcl
check {
  type     = "http"
  path     = "/health"
  interval = "10s"
  timeout  = "2s"
  
  check_restart {
    limit = 3
    grace = "10s"
  }
}
```

### 3. Automatic Rescheduling

If a node fails, allocations reschedule automatically:

```hcl
reschedule {
  attempts       = 5
  interval       = "10m"
  delay          = "30s"
  delay_function = "exponential"
  max_delay      = "2m"
}
```

### 4. Canary Deployments

Zero-downtime updates:

```hcl
update {
  max_parallel     = 1
  canary           = 1
  auto_promote     = true
  auto_revert      = true
  min_healthy_time = "30s"
}
```

## 🔧 Load Balancer Configuration

### Application Load Balancer (ALB)

Create an ALB to distribute traffic:

**Target Group:**
- Protocol: HTTP
- Port: 8080
- Health check: `/health`
- Targets: All Nomad client nodes running frontend

**Listener:**
- Protocol: HTTP (or HTTPS with certificate)
- Port: 80 (or 443)
- Forward to target group

**Security Group:**
```
Inbound:
- Port 80/443 from 0.0.0.0/0
- Port 8080 from ALB security group

Outbound:
- All traffic
```

### Network Load Balancer (NLB)

For TCP load balancing:

**Target Group:**
- Protocol: TCP
- Port: 8080
- Health check: HTTP on `/health`

## 📊 Monitoring

### Service Status

```bash
# Overall job status
nomad job status microservices-app-nomad-sd-aws

# Service health
nomad service info backend-api
nomad service info frontend-web

# Allocation status
nomad alloc status <alloc-id>
```

### Logs

```bash
# View logs
nomad alloc logs -f <alloc-id> backend
nomad alloc logs -f <alloc-id> frontend

# Stderr logs
nomad alloc logs -stderr <alloc-id> backend
```

### Metrics

```bash
# Node resources
nomad node status <node-id>

# Job metrics
nomad job status -verbose microservices-app-nomad-sd-aws
```

## 🐛 Troubleshooting

### Issue: Services Not Registering

**Symptoms:**
- `nomad service list` doesn't show services
- Frontend can't discover backend

**Solutions:**

1. **Check service block:**
   ```bash
   nomad job inspect microservices-app-nomad-sd-aws | jq '.Job.TaskGroups[].Services'
   ```

2. **Verify allocation is running:**
   ```bash
   nomad job allocs microservices-app-nomad-sd-aws
   ```

3. **Check health checks:**
   ```bash
   nomad alloc status <alloc-id>
   ```

### Issue: Uneven Distribution

**Symptoms:**
- All allocations on same AZ
- Not spreading across nodes

**Solutions:**

1. **Check spread configuration:**
   ```hcl
   spread {
     attribute = "${node.datacenter}"
     weight    = 100
   }
   ```

2. **Verify node datacenters:**
   ```bash
   nomad node status -verbose
   ```

3. **Check constraints:**
   ```bash
   nomad job inspect microservices-app-nomad-sd-aws | jq '.Job.Constraints'
   ```

### Issue: Template Not Updating

**Symptoms:**
- Frontend still using old backend addresses
- Service discovery not working

**Solutions:**

1. **Check template rendering:**
   ```bash
   nomad alloc fs <alloc-id> local/backend-config.env
   ```

2. **Verify change_mode:**
   ```hcl
   template {
     change_mode = "restart"  # or "signal"
   }
   ```

3. **Force restart:**
   ```bash
   nomad alloc restart <alloc-id>
   ```

### Issue: Health Checks Failing

**Symptoms:**
- Services marked as unhealthy
- Constant restarts

**Solutions:**

1. **Test health endpoint:**
   ```bash
   nomad alloc exec <alloc-id> curl http://localhost:3000/health
   ```

2. **Check logs:**
   ```bash
   nomad alloc logs <alloc-id> backend
   ```

3. **Adjust health check timing:**
   ```hcl
   check {
     interval = "30s"  # Increase interval
     timeout  = "5s"   # Increase timeout
   }
   ```

## 🔐 Security Best Practices

### 1. Network Security

```hcl
# Use private subnets for Nomad clients
# Only expose load balancer publicly
```

### 2. IAM Roles

Attach IAM roles to EC2 instances:
- Read-only access to ECR (if using)
- CloudWatch Logs write access
- Systems Manager access

### 3. Secrets Management

Use Nomad templates with Vault:

```hcl
template {
  data = <<EOH
{{ with secret "secret/data/app/config" }}
DATABASE_URL={{ .Data.data.db_url }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
EOH
  destination = "secrets/config.env"
  env         = true
}
```

### 4. Resource Limits

Set appropriate limits:

```hcl
resources {
  cpu    = 500
  memory = 512
  
  # Prevent resource exhaustion
}
```

## 📈 Scaling

### Manual Scaling

```bash
# Scale backend to 5 instances
nomad job scale microservices-app-nomad-sd-aws backend 5

# Scale frontend to 5 instances
nomad job scale microservices-app-nomad-sd-aws frontend 5
```

### Auto-scaling with AWS

Use AWS Auto Scaling Groups:

1. **Create Launch Template** with Nomad client configuration
2. **Create Auto Scaling Group** across multiple AZs
3. **Configure scaling policies** based on CPU/memory
4. **Nomad automatically** schedules on new nodes

## 💰 Cost Optimization

### 1. Use Spot Instances

For non-critical workloads:

```hcl
constraint {
  attribute = "${meta.instance_type}"
  operator  = "regexp"
  value     = "spot"
}
```

### 2. Graviton Instances

ARM64 instances are ~20% cheaper:

```hcl
constraint {
  attribute = "${attr.cpu.arch}"
  value     = "arm64"
}
```

### 3. Right-sizing

Monitor and adjust resources:

```bash
# Check actual usage
nomad alloc status -stats <alloc-id>
```

## 📚 Additional Resources

- [Nomad Service Discovery](https://www.nomadproject.io/docs/service-discovery)
- [Nomad on AWS](https://www.nomadproject.io/docs/install/production/deployment-guide)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/)
- [Nomad Templates](https://www.nomadproject.io/docs/job-specification/template)

## 🎯 Summary

This deployment provides:

✅ **High Availability** - Multiple instances across AZs
✅ **Service Discovery** - Nomad native (no Consul required)
✅ **Zero Downtime** - Canary deployments with auto-rollback
✅ **AWS Optimized** - Multi-AZ, Graviton support
✅ **Auto-healing** - Automatic rescheduling on failures
✅ **Scalable** - Easy horizontal scaling
✅ **Cost Effective** - Spot instances and Graviton support