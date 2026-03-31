job "microservices-app-consul-dns" {
  datacenters = ["dc1"]
  type        = "service"

  # This job will run on both ARM64 and AMD64 nodes
  constraint {
    operator = "regexp"
    attribute = "${attr.cpu.arch}"
    value     = "amd64|arm64"
  }

  group "backend" {
    count = 2

    network {
      port "http" {
        to = 3000
      }
    }

    # Register service with Consul for DNS discovery
    service {
      name = "backend-api"
      port = "http"
      
      tags = [
        "backend",
        "api",
        "microservices"
      ]

      # Health check
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "backend" {
      driver = "docker"

      config {
        image = "aimeeu/microservices-backend:latest"
        ports = ["http"]
        
        # Force pull to get the correct architecture image
        force_pull = false
      }

      env {
        PORT     = "${NOMAD_PORT_http}"
        NODE_ENV = "production"
      }

      resources {
        cpu    = 500
        memory = 256
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    # Restart policy
    restart {
      attempts = 3
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }

    # Update strategy
    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }
  }

  group "frontend" {
    count = 2

    network {
      port "http" {
        static = 8080
        to     = 80
      }
    }

    # Register service with Consul for DNS discovery
    service {
      name = "frontend-web"
      port = "http"
      
      tags = [
        "frontend",
        "web",
        "microservices",
        "urlprefix-/"
      ]

      # Health check
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "aimeeu/microservices-frontend:latest"
        ports = ["http"]
        
        # DNS configuration to use Consul DNS
        # This allows the frontend to resolve backend-api.service.consul
        dns_servers = ["${attr.unique.network.ip-address}"]
        dns_search_domains = ["service.consul"]
        
        # Force pull to get the correct architecture image
        force_pull = false
      }

      # Template to configure backend API URL using Consul DNS
      template {
        data = <<EOH
# Backend API can be accessed via Consul DNS
# backend-api.service.consul resolves to all healthy backend instances
BACKEND_API_URL=http://backend-api.service.consul:{{ range service "backend-api" }}{{ .Port }}{{ end }}
EOH
        destination = "local/env.txt"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 128
      }

      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    # Restart policy
    restart {
      attempts = 3
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }

    # Update strategy
    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }
  }
}