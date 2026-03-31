job "microservices-app-nomad-sd-aws" {
  # Deploy to multiple AWS datacenters/regions
  datacenters = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  type = "service"

  # Multi-architecture support for AWS (AMD64 and ARM64/Graviton)
  constraint {
    operator = "regexp"
    attribute = "${attr.cpu.arch}"
    value     = "amd64|arm64"
  }

  # Spread allocations across AWS availability zones for high availability
  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }

  # Backend service group
  group "backend" {
    # Run multiple instances across different nodes
    count = 3

    # Spread backend instances across different nodes
    spread {
      attribute = "${node.unique.id}"
      weight    = 100
    }

    # Constraint: Don't run multiple backend instances on same node
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # Network configuration
    network {
      mode = "host"
      
      port "http" {
        # Dynamic port allocation
        to = 3000
      }
    }

    # Register service with Nomad native service discovery
    service {
      name = "backend-api"
      port = "http"
      
      tags = [
        "backend",
        "api",
        "microservices",
        "aws",
        "version-1.0"
      ]

      # Service metadata for discovery
      meta {
        version     = "1.0.0"
        environment = "production"
        region      = "${node.datacenter}"
      }

      # Health check
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
        
        check_restart {
          limit           = 3
          grace           = "10s"
          ignore_warnings = false
        }
      }
    }

    # Backend task
    task "backend" {
      driver = "docker"

      config {
        image = "aimeeu/microservices-backend:latest"
        ports = ["http"]
        
        # Force pull to ensure latest image
        force_pull = false
        
        # AWS-specific: Use IMDSv2 for instance metadata
        extra_hosts = ["metadata.google.internal:169.254.169.254"]
      }

      # Environment variables
      env {
        PORT           = "${NOMAD_PORT_http}"
        NODE_ENV       = "production"
        AWS_REGION     = "${node.datacenter}"
        INSTANCE_ID    = "${node.unique.name}"
        ALLOCATION_ID  = "${NOMAD_ALLOC_ID}"
      }

      # Resource allocation - optimized for AWS instances
      resources {
        cpu    = 500  # MHz
        memory = 512  # MB
      }

      # Logging configuration
      logs {
        max_files     = 10
        max_file_size = 15  # MB
      }
    }

    # Restart policy
    restart {
      attempts = 3
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }

    # Reschedule policy for AWS node failures
    reschedule {
      attempts       = 5
      interval       = "10m"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # Update strategy for zero-downtime deployments
    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
    }

    # Ephemeral disk for temporary files
    ephemeral_disk {
      size    = 300  # MB
      migrate = true
    }
  }

  # Frontend service group
  group "frontend" {
    # Run multiple instances for high availability
    count = 3

    # Spread frontend instances across different nodes
    spread {
      attribute = "${node.unique.id}"
      weight    = 100
    }

    # Constraint: Don't run multiple frontend instances on same node
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # Network configuration
    network {
      mode = "host"
      
      port "http" {
        # Static port for load balancer
        static = 8080
        to     = 80
      }
    }

    # Register service with Nomad native service discovery
    service {
      name = "frontend-web"
      port = "http"
      
      tags = [
        "frontend",
        "web",
        "microservices",
        "aws",
        "urlprefix-/",
        "version-1.0"
      ]

      # Service metadata
      meta {
        version     = "1.0.0"
        environment = "production"
        region      = "${node.datacenter}"
      }

      # Health check
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
        
        check_restart {
          limit           = 3
          grace           = "10s"
          ignore_warnings = false
        }
      }
    }

    # Frontend task
    task "frontend" {
      driver = "docker"

      config {
        image = "aimeeu/microservices-frontend:latest"
        ports = ["http"]
        
        # Force pull to ensure latest image
        force_pull = false
      }

      # Template to generate config.js with backend API URL from Nomad service discovery
      template {
        data = <<EOH
// Backend API Configuration
// Generated by Nomad template at runtime
window.APP_CONFIG = {
{{- range nomadService "backend-api" }}
  {{- if .Healthy }}
    BACKEND_API_URL: 'http://{{ .Address }}:{{ .Port }}'
  {{- end }}
{{- end }}
{{- if not (nomadService "backend-api") }}
    BACKEND_API_URL: 'http://localhost:3000'
{{- end }}
};
EOH
        destination = "local/config.js"
        change_mode = "restart"
      }

      # Additional template for Nginx configuration with backend discovery
      template {
        data = <<EOH
# Nginx upstream configuration for backend
upstream backend_servers {
{{- range nomadService "backend-api" }}
  {{- if .Healthy }}
    server {{ .Address }}:{{ .Port }} max_fails=3 fail_timeout=30s;
  {{- end }}
{{- end }}
}

server {
    listen 80;
    server_name _;
    
    location /api/ {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOH
        destination = "local/nginx-backend.conf"
        change_mode = "signal"
        change_signal = "SIGHUP"
      }

      # Environment variables
      env {
        AWS_REGION     = "${node.datacenter}"
        INSTANCE_ID    = "${node.unique.name}"
        ALLOCATION_ID  = "${NOMAD_ALLOC_ID}"
      }

      # Resource allocation
      resources {
        cpu    = 300  # MHz
        memory = 256  # MB
      }

      # Logging configuration
      logs {
        max_files     = 10
        max_file_size = 15  # MB
      }
    }

    # Restart policy
    restart {
      attempts = 3
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }

    # Reschedule policy for AWS node failures
    reschedule {
      attempts       = 5
      interval       = "10m"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # Update strategy for zero-downtime deployments
    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
      canary            = 1
    }

    # Ephemeral disk
    ephemeral_disk {
      size    = 300  # MB
      migrate = true
    }
  }

  # Migrate strategy for AWS node maintenance
  migrate {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "30s"
    healthy_deadline = "5m"
  }
}