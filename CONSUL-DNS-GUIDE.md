# Consul DNS Service Discovery Guide

This guide explains how to deploy the microservices application using Consul DNS for service discovery (without Consul Connect service mesh).

## 📋 Overview

Consul DNS allows services to discover each other using DNS queries. Services register with Consul, and other services can resolve them using the `.service.consul` domain.

**Example:**
- Backend service registers as `backend-api`
- Frontend can access it via `backend-api.service.consul`

## 🔧 Prerequisites

1. **Nomad cluster** with Docker driver enabled
2. **Consul agent** running on all Nomad clients
3. **Consul DNS** configured (default port 8600)
4. Docker images pushed to Docker Hub

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Consul DNS                        │
│              (Service Registry)                     │
└─────────────────────────────────────────────────────┘
           ▲                           ▲
           │ Register                  │ Query
           │                           │
    ┌──────┴──────┐            ┌──────┴──────┐
    │   Backend   │            │  Frontend   │
    │   Service   │            │   Service   │
    │             │            │             │
    │ backend-api │◄───────────│ Queries:    │
    │.service.    │   HTTP     │ backend-api │
    │ consul      │            │.service.    │
    │             │            │ consul      │
    └─────────────┘            └─────────────┘
```

## 🚀 Deployment

### Step 1: Update Docker Hub Username

Edit `microservices-app-consul-dns.nomad.hcl` and replace `your-dockerhub-username` with your actual username:

```hcl
config {
  image = "your-dockerhub-username/microservices-backend:latest"
  # ...
}
```

### Step 2: Validate the Job

```bash
nomad job validate microservices-app-consul-dns.nomad.hcl
```

### Step 3: Plan the Deployment

```bash
nomad job plan microservices-app-consul-dns.nomad.hcl
```

### Step 4: Run the Job

```bash
nomad job run microservices-app-consul-dns.nomad.hcl
```

### Step 5: Verify Deployment

```bash
# Check job status
nomad job status microservices-app-consul-dns

# Check service registration in Consul
consul catalog services

# Query backend service
consul catalog service backend-api

# Query frontend service
consul catalog service frontend-web
```

## 🔍 How It Works

### Backend Service Registration

The backend service registers with Consul automatically:

```hcl
service {
  name = "backend-api"
  port = "http"
  
  check {
    type     = "http"
    path     = "/health"
    interval = "10s"
    timeout  = "2s"
  }
}
```

### Frontend DNS Configuration

The frontend container is configured to use Consul DNS:

```hcl
config {
  # Use Consul DNS for service resolution
  dns_servers = ["${attr.unique.network.ip-address}"]
  dns_search_domains = ["service.consul"]
}
```

### DNS Resolution

When the frontend needs to access the backend:

1. Frontend queries: `backend-api.service.consul`
2. Consul DNS returns IP addresses of all healthy backend instances
3. Frontend connects to one of the backend instances

## 🧪 Testing DNS Resolution

### From Within a Container

```bash
# Get allocation ID
ALLOC_ID=$(nomad job allocs microservices-app-consul-dns | grep frontend | head -1 | awk '{print $1}')

# Execute DNS query inside the container
nomad alloc exec $ALLOC_ID nslookup backend-api.service.consul

# Or using dig
nomad alloc exec $ALLOC_ID dig backend-api.service.consul
```

### From Nomad Client

```bash
# Query Consul DNS directly (port 8600)
dig @127.0.0.1 -p 8600 backend-api.service.consul

# Or using nslookup
nslookup backend-api.service.consul 127.0.0.1
```

### Expected Output

```
Server:         127.0.0.1
Address:        127.0.0.1#8600

Name:   backend-api.service.consul
Address: 172.26.64.101
Name:   backend-api.service.consul
Address: 172.26.64.102
```

## 📊 Service Discovery Features

### Load Balancing

Consul DNS returns multiple IP addresses for services with multiple instances. The client (or DNS resolver) can:
- Round-robin between instances
- Use the first available instance
- Implement custom load balancing logic

### Health Checking

Only healthy instances are returned in DNS queries:

```hcl
check {
  type     = "http"
  path     = "/health"
  interval = "10s"
  timeout  = "2s"
}
```

If a backend instance fails its health check, Consul automatically removes it from DNS responses.

### Service Tags

Services can be queried by tags:

```bash
# Query services with specific tag
dig @127.0.0.1 -p 8600 backend.backend-api.service.consul
```

## 🔧 Configuration Options

### DNS TTL

Control how long DNS responses are cached:

```hcl
service {
  name = "backend-api"
  
  meta {
    dns_ttl = "10s"
  }
}
```

### Custom DNS Search Domains

Add additional search domains:

```hcl
config {
  dns_servers = ["${attr.unique.network.ip-address}"]
  dns_search_domains = ["service.consul", "node.consul"]
}
```

### DNS Options

Configure DNS resolver behavior:

```hcl
config {
  dns_servers = ["${attr.unique.network.ip-address}"]
  dns_options = ["ndots:1", "timeout:2", "attempts:2"]
}
```

## 🐛 Troubleshooting

### Issue: DNS Resolution Fails

**Symptoms:**
- Frontend can't connect to backend
- DNS queries return no results

**Solutions:**

1. **Check Consul agent is running:**
   ```bash
   consul members
   ```

2. **Verify service registration:**
   ```bash
   consul catalog services
   consul catalog service backend-api
   ```

3. **Check DNS configuration:**
   ```bash
   # Inside container
   cat /etc/resolv.conf
   ```

4. **Test DNS resolution:**
   ```bash
   nomad alloc exec <alloc-id> nslookup backend-api.service.consul
   ```

### Issue: Services Not Registering

**Symptoms:**
- Service doesn't appear in Consul catalog
- `consul catalog services` doesn't show your service

**Solutions:**

1. **Check Nomad-Consul integration:**
   ```bash
   nomad agent-info | grep consul
   ```

2. **Verify service block in job spec:**
   ```hcl
   service {
     name = "backend-api"  # Must be defined
     port = "http"         # Must match network port
   }
   ```

3. **Check allocation logs:**
   ```bash
   nomad alloc logs <alloc-id>
   ```

### Issue: Health Checks Failing

**Symptoms:**
- Service registered but not returned in DNS queries
- Consul UI shows service as unhealthy

**Solutions:**

1. **Check health check endpoint:**
   ```bash
   curl http://<service-ip>:<port>/health
   ```

2. **Verify health check configuration:**
   ```hcl
   check {
     type     = "http"
     path     = "/health"      # Must be correct
     interval = "10s"
     timeout  = "2s"           # Increase if needed
   }
   ```

3. **View health check logs in Consul:**
   ```bash
   consul monitor
   ```

## 📈 Monitoring

### View Service Health

```bash
# List all services
consul catalog services

# Get service details
consul catalog service backend-api -detailed

# Check service health
consul health service backend-api
```

### Monitor DNS Queries

```bash
# Enable Consul DNS logging
consul monitor -log-level=debug | grep dns
```

### Nomad Service Status

```bash
# Check job status
nomad job status microservices-app-consul-dns

# View service registrations
nomad service list

# Get service details
nomad service info backend-api
```

## 🔐 Security Considerations

### DNS Security

1. **Limit DNS access** to trusted networks
2. **Use Consul ACLs** to control service registration
3. **Enable TLS** for Consul communication

### Network Policies

```hcl
# Example: Restrict backend access
service {
  name = "backend-api"
  
  meta {
    allowed_clients = "frontend-web"
  }
}
```

## 📚 Additional Resources

- [Consul DNS Documentation](https://www.consul.io/docs/discovery/dns)
- [Nomad Service Discovery](https://www.nomadproject.io/docs/service-discovery)
- [Consul Service Configuration](https://www.consul.io/docs/discovery/services)

## 🆚 Consul DNS vs Consul Connect

| Feature | Consul DNS | Consul Connect |
|---------|-----------|----------------|
| Service Discovery | ✅ Yes | ✅ Yes |
| Load Balancing | Client-side | Proxy-based |
| Encryption | ❌ No | ✅ mTLS |
| Authorization | ❌ No | ✅ Intentions |
| Complexity | Low | Medium |
| Performance | Fast | Slight overhead |
| Use Case | Simple discovery | Secure service mesh |

Choose **Consul DNS** when:
- You need simple service discovery
- Performance is critical
- You don't need service-to-service encryption
- You want minimal complexity

Choose **Consul Connect** when:
- You need encrypted service communication
- You want fine-grained access control
- You need observability features
- Security is a top priority