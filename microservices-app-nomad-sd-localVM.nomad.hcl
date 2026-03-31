job "microservices-app-local" {
  # Nomad dev mode uses "dc1" datacenter by default
  datacenters = ["dc1"]
  
  type = "service"

  # Backend service group
  group "backend" {
    # Single instance for local development
    count = 1

    # Network configuration
    network {
      mode = "bridge"
      
      port "http" {
        # Use static port for easier access
        static = 3000
        to     = 3000
      }
    }

    # Register service with Nomad native service discovery
    service {
      name = "backend-api"
      port = "http"
      
      tags = [
        "backend",
        "api",
        "local-dev"
      ]

      # Service metadata
      meta {
        version     = "1.0.0"
        environment = "development"
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
        image = "your-dockerhub-username/microservices-backend:latest"
        ports = ["http"]
        
        # For local development, you can use locally built images
        # To use local image instead of Docker Hub:
        # 1. Build: docker build -t microservices-backend:latest ./backend
        # 2. Change image to: image = "microservices-backend:latest"
        # 3. Set: force_pull = false
        
        force_pull = false
      }

      # Environment variables
      env {
        PORT     = "3000"
        NODE_ENV = "development"
      }

      # Resource allocation - lighter for local VM
      resources {
        cpu    = 500  # MHz
        memory = 256  # MB
      }

      # Logging
      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    # Restart policy
    restart {
      attempts = 2
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }
  }

  # Frontend service group
  group "frontend" {
    # Single instance for local development
    count = 1

    # Network configuration
    network {
      mode = "bridge"
      
      port "http" {
        # Use static port for easier access
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
        "local-dev"
      ]

      # Service metadata
      meta {
        version     = "1.0.0"
        environment = "development"
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
        image = "your-dockerhub-username/microservices-frontend:latest"
        ports = ["http"]
        
        # For local development with local image:
        # 1. Build: docker build -t microservices-frontend:latest ./frontend
        # 2. Change image to: image = "microservices-frontend:latest"
        # 3. Set: force_pull = false
        
        force_pull = false
      }

      # Template to configure backend API URL using Nomad service discovery
      template {
        data = <<EOH
# Backend service discovery via Nomad
{{- range nomadService "backend-api" }}
  {{- if .Healthy }}
BACKEND_API_HOST={{ .Address }}
BACKEND_API_PORT={{ .Port }}
BACKEND_API_URL=http://{{ .Address }}:{{ .Port }}
  {{- end }}
{{- end }}

# Fallback if backend not found
{{- if not (nomadService "backend-api") }}
BACKEND_API_URL=http://localhost:3000
{{- end }}
EOH
        destination = "local/backend-config.env"
        env         = true
        change_mode = "restart"
      }

      # Environment variables
      env {
        NODE_ENV = "development"
      }

      # Resource allocation - lighter for local VM
      resources {
        cpu    = 300  # MHz
        memory = 128  # MB
      }

      # Logging
      logs {
        max_files     = 5
        max_file_size = 10
      }
    }

    # Restart policy
    restart {
      attempts = 2
      delay    = "15s"
      interval = "5m"
      mode     = "fail"
    }
  }
}