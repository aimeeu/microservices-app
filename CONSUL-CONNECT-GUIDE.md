# Consul Connect Service Mesh Guide

This guide explains how to deploy the microservices application using Consul Connect service mesh for secure service-to-service communication and service discovery.

## 📋 Overview

Consul Connect is a service mesh solution that provides:
- **Service Discovery** - Services find each other automatically
- **Mutual TLS (mTLS)** - Encrypted service-to-service communication
- **Authorization** - Fine-grained access control with intentions
- **Observability** - Traffic metrics and distributed tracing

## 🆚 Consul DNS vs Consul Connect

### Service Discovery Comparison

| Aspect | Consul DNS | Consul Connect |
|--------|-----------|----------------|
| **Discovery Method** | DNS queries (`.service.consul`) | Sidecar proxy with service mesh |
| **Connection** | Direct service-to-service | Through Envoy sidecar proxies |
| **Encryption** | ❌ No (plain HTTP) | ✅ Yes (automatic mTLS) |
| **Authorization** | ❌ No | ✅ Yes (intentions) |
| **Load Balancing** | Client-side (DNS round-robin) | Proxy-based (Envoy) |
| **Health Checks** | ✅ Yes | ✅ Yes |
| **Observability** | Basic | Advanced (metrics, tracing) |
| **Complexity** | Low | Medium |
| **Performance** | Fast (direct connection) | Slight overhead (proxy hop) |
| **Use Case** | Simple internal services | Security-critical services |

### How Service Discovery Works

#### Consul DNS
```
Frontend Container
    │
    ├─> DNS Query: backend-api.service.consul
    │   └─> Consul DNS returns: 172.26.64.101, 172.26.64.102
    │
    └─> Direct HTTP connection to backend
        └─> http://172.26.64.101:3000/api/items
```

#### Consul Connect
```
Frontend Container
    │
    └─> HTTP to localhost:3000 (sidecar proxy)
        │
        └─> Frontend Sidecar (Envoy)
            │
            ├─> Service Discovery via Consul
            ├─> mTLS Handshake
            ├─> Authorization Check (intentions)
            │
            └─> Backend Sidecar (Envoy)
                │
                └─> Backend Container
                    └─> http://localhost:3000/api/items
```

### Key Differences

**1. Connection Path**
- **DNS**: Frontend → Backend (direct)
- **Connect**: Frontend → Frontend Sidecar → Backend Sidecar → Backend

**2. Service Discovery**
- **DNS**: Query Consul DNS server, get IP addresses
- **Connect**: Sidecar queries Consul, maintains connection pool

**3. Security**
- **DNS**: No encryption, no authentication
- **Connect**: Automatic mTLS, certificate rotation, intentions

**4. Configuration**
- **DNS**: Configure DNS servers in container
- **Connect**: Configure sidecar proxy and upstreams

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Consul Server                        │
│  - Service Registry                                     │
│  - Certificate Authority (CA)                           │
│  - Intentions (Authorization Rules)                     │
└─────────────────────────────────────────────────────────┘
           ▲                           ▲
           │                           │
    ┌──────┴──────┐            ┌──────┴──────┐
    │   Backend   │            │  Frontend   │
    │   Group     │            │   Group     │
    │             │            │             │
    │ ┌─────────┐ │            │ ┌─────────┐ │
    │ │ Backend │ │            │ │Frontend │ │
    │ │Container│ │            │ │Container│ │
    │ └────┬────┘ │            │ └────┬────┘ │
    │      │      │            │      │      │
    │ ┌────┴────┐ │   mTLS     │ ┌────┴────┐ │
    │ │ Envoy   │◄├────────────┤─│  Envoy  │ │
    │ │ Sidecar │ │            │ │ Sidecar │ │
    │ └─────────┘ │            │ └─────────┘ │
    └─────────────┘            └─────────────┘
```

## 🔧 Prerequisites

1. **Nomad cluster** with Docker driver enabled
2. **Consul agent** running on all Nomad clients
3. **Consul Connect** enabled in Consul configuration
4. **CNI plugins** installed for bridge networking
5. Docker images pushed to Docker Hub

### Verify Consul Connect

```bash
# Check Consul Connect is enabled
consul connect ca get-config

# Verify CNI plugins
ls -la /opt/cni/bin/
```

## 🚀 Deployment

### Step 1: Review the Job Specification

The `microservices-app-consul.nomad.hcl` file includes:

**Backend Service:**
```hcl
service {
  name = "backend-api"
  port = "3000"
  
  connect {
    sidecar_service {}  # Automatic Envoy sidecar
  }
}
```

**Frontend Service with Upstream:**
```hcl
service {
  name = "frontend-web"
  port = "80"
  
  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "backend-api"
          local_bind_port  = 3000  # Frontend accesses backend via localhost:3000
        }
      }
    }
  }
}
```

### Step 2: Update Docker Hub Username

Edit `microservices-app-consul.nomad.hcl`:

```hcl
config {
  image = "your-dockerhub-username/microservices-backend:latest"
}
```

### Step 3: Deploy the Job

```bash
# Validate
nomad job validate microservices-app-consul.nomad.hcl

# Plan
nomad job plan microservices-app-consul.nomad.hcl

# Run
nomad job run microservices-app-consul.nomad.hcl
```

### Step 4: Verify Deployment

```bash
# Check job status
nomad job status microservices-app-consul

# Verify services in Consul
consul catalog services

# Check Connect proxies
consul connect proxy list
```

## 🔐 Security Features

### 1. Automatic mTLS

All service-to-service communication is encrypted:

```bash
# View certificates
nomad alloc exec <backend-alloc-id> \
  cat /secrets/connect-proxy-backend-api.crt

# Check certificate details
openssl x509 -in cert.pem -text -noout
```

### 2. Service Intentions

Control which services can communicate:

```bash
# Allow frontend to access backend
consul intention create frontend-web backend-api

# Deny all other access to backend
consul intention create -deny '*' backend-api

# List intentions
consul intention list

# Check if connection is allowed
consul intention check frontend-web backend-api
```

### 3. Certificate Rotation

Consul automatically rotates certificates:

```bash
# View CA configuration
consul connect ca get-config

# Certificates are rotated based on TTL (default: 72 hours)
```

## 🔍 How It Works

### Service Registration

When a service starts:

1. **Service registers** with Consul
2. **Sidecar proxy** (Envoy) is automatically deployed
3. **Certificates** are issued by Consul CA
4. **Proxy configuration** is pushed from Consul

### Service-to-Service Communication

When frontend calls backend:

1. **Frontend** makes HTTP request to `localhost:3000`
2. **Frontend sidecar** intercepts the request
3. **Service discovery** - Sidecar queries Consul for backend instances
4. **mTLS handshake** - Sidecars establish encrypted connection
5. **Authorization** - Consul checks intentions
6. **Request forwarded** to backend sidecar
7. **Backend sidecar** forwards to backend container
8. **Response** flows back through the same path

### Upstream Configuration

The frontend's upstream configuration:

```hcl
upstreams {
  destination_name = "backend-api"  # Service name in Consul
  local_bind_port  = 3000           # Local port to bind
}
```

This means:
- Frontend accesses backend via `http://localhost:3000`
- Sidecar proxy handles service discovery and routing
- No need to know backend IP addresses

## 🧪 Testing

### Test Service Communication

```bash
# Get frontend allocation
FRONTEND_ALLOC=$(nomad job allocs microservices-app-consul | grep frontend | head -1 | awk '{print $1}')

# Test backend connection from frontend
nomad alloc exec $FRONTEND_ALLOC curl http://localhost:3000/health

# Should return backend health status
```

### Verify mTLS

```bash
# Check sidecar proxy logs
nomad alloc logs -f $FRONTEND_ALLOC connect-proxy-frontend-web

# Look for TLS handshake messages
```

### Test Intentions

```bash
# Deny frontend access to backend
consul intention create -deny frontend-web backend-api

# Try to access backend from frontend
nomad alloc exec $FRONTEND_ALLOC curl http://localhost:3000/health
# Should fail with connection refused

# Allow access again
consul intention create -allow frontend-web backend-api
```

## 📊 Monitoring

### View Service Mesh Topology

```bash
# List all Connect services
consul catalog services -tags

# View service details
consul catalog service backend-api -detailed

# Check proxy status
consul connect proxy list
```

### Metrics

Envoy sidecars expose metrics:

```bash
# Access Envoy admin interface
nomad alloc exec $FRONTEND_ALLOC curl http://localhost:19000/stats

# View connection stats
nomad alloc exec $FRONTEND_ALLOC curl http://localhost:19000/clusters
```

### Logs

```bash
# View sidecar logs
nomad alloc logs -f <alloc-id> connect-proxy-<service-name>

# View service logs
nomad alloc logs -f <alloc-id> <task-name>
```

## 🐛 Troubleshooting

### Issue: Sidecar Proxy Not Starting

**Symptoms:**
- Allocation fails to start
- "connect-proxy" task in pending state

**Solutions:**

1. **Check CNI plugins:**
   ```bash
   ls -la /opt/cni/bin/
   # Should include: bridge, loopback, portmap
   ```

2. **Verify bridge networking:**
   ```bash
   nomad node status -self | grep bridge
   ```

3. **Check Consul Connect:**
   ```bash
   consul connect ca get-config
   ```

### Issue: Services Can't Communicate

**Symptoms:**
- Frontend can't reach backend
- Connection refused errors

**Solutions:**

1. **Check intentions:**
   ```bash
   consul intention list
   consul intention check frontend-web backend-api
   ```

2. **Verify upstream configuration:**
   ```hcl
   upstreams {
     destination_name = "backend-api"  # Must match service name
     local_bind_port  = 3000           # Must match frontend config
   }
   ```

3. **Check sidecar logs:**
   ```bash
   nomad alloc logs <alloc-id> connect-proxy-frontend-web
   ```

### Issue: Certificate Errors

**Symptoms:**
- TLS handshake failures
- Certificate validation errors

**Solutions:**

1. **Check CA configuration:**
   ```bash
   consul connect ca get-config
   ```

2. **Verify certificate:**
   ```bash
   nomad alloc exec <alloc-id> \
     openssl x509 -in /secrets/connect-proxy-*.crt -text -noout
   ```

3. **Restart allocation** to get new certificates:
   ```bash
   nomad alloc restart <alloc-id>
   ```

## 🔧 Configuration Options

### Custom Proxy Configuration

```hcl
connect {
  sidecar_service {
    proxy {
      config {
        # Custom Envoy configuration
        envoy_stats_bind_addr = "0.0.0.0:9102"
      }
      
      upstreams {
        destination_name = "backend-api"
        local_bind_port  = 3000
        
        # Datacenter-aware routing
        datacenter = "dc1"
        
        # Mesh gateway mode
        mesh_gateway {
          mode = "local"
        }
      }
    }
  }
}
```

### Intention Configuration

```bash
# Create intention with metadata
consul intention create \
  -allow \
  -meta "description=Frontend to Backend" \
  frontend-web backend-api

# Create intention with specific permissions
consul intention create \
  -allow \
  -http-method GET \
  -http-path-prefix "/api" \
  frontend-web backend-api
```

### Certificate TTL

```bash
# Update CA configuration
consul connect ca set-config \
  -config-file ca-config.json

# ca-config.json
{
  "LeafCertTTL": "72h",
  "IntermediateCertTTL": "8760h"
}
```

## 📈 Best Practices

### 1. Use Intentions for Authorization

```bash
# Default deny all
consul intention create -deny '*' '*'

# Explicitly allow required connections
consul intention create -allow frontend-web backend-api
```

### 2. Monitor Sidecar Health

```hcl
check {
  type     = "http"
  port     = "connect-proxy"
  path     = "/ready"
  interval = "10s"
  timeout  = "2s"
}
```

### 3. Configure Resource Limits

```hcl
sidecar_task {
  resources {
    cpu    = 200
    memory = 128
  }
}
```

### 4. Enable Metrics Collection

```hcl
proxy {
  config {
    envoy_prometheus_bind_addr = "0.0.0.0:9102"
  }
}
```

## 🔐 Security Considerations

### 1. Principle of Least Privilege

Only allow necessary service connections:

```bash
# Deny all by default
consul intention create -deny '*' '*'

# Allow only required connections
consul intention create -allow frontend-web backend-api
```

### 2. Certificate Management

- Consul automatically rotates certificates
- Monitor certificate expiration
- Use appropriate TTL values

### 3. Network Segmentation

Use Consul's datacenter and namespace features:

```hcl
service {
  name = "backend-api"
  namespace = "production"
  
  connect {
    sidecar_service {}
  }
}
```

## 📚 Additional Resources

- [Consul Connect Documentation](https://www.consul.io/docs/connect)
- [Nomad Connect Integration](https://www.nomadproject.io/docs/integrations/consul-connect)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs)
- [Service Mesh Patterns](https://www.consul.io/docs/connect/observability)

## 🎯 When to Use Consul Connect

Choose **Consul Connect** when you need:

✅ **Encrypted service communication** (mTLS)
✅ **Fine-grained access control** (intentions)
✅ **Zero-trust security model**
✅ **Advanced observability** (metrics, tracing)
✅ **Multi-datacenter service mesh**
✅ **Compliance requirements** (encryption at rest/transit)

Choose **Consul DNS** when you need:

✅ **Simple service discovery**
✅ **Minimal overhead**
✅ **Fast performance** (no proxy hop)
✅ **Legacy application support**
✅ **Internal-only services** (already on secure network)

## 🔄 Migration Path

### From Consul DNS to Consul Connect

1. **Deploy with Connect** alongside DNS
2. **Test thoroughly** in staging environment
3. **Update intentions** to allow traffic
4. **Monitor performance** and metrics
5. **Gradually migrate** services
6. **Remove DNS configuration** once stable

### Hybrid Approach

You can use both simultaneously:
- **Consul Connect** for external-facing services
- **Consul DNS** for internal services

```hcl
# Service with both DNS and Connect
service {
  name = "backend-api"
  port = "http"
  
  # DNS registration
  tags = ["dns"]
  
  # Connect service mesh
  connect {
    sidecar_service {}
  }
}