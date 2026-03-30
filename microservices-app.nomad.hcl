job "microservices-app" {
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

    service {
      name = "backend-api"
      port = "http"
      
      tags = [
        "backend",
        "api",
        "microservices"
      ]

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
        image = "your-dockerhub-username/microservices-backend:latest"
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

    service {
      name = "frontend-web"
      port = "http"
      
      tags = [
        "frontend",
        "web",
        "microservices",
        "urlprefix-/"
      ]

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
        image = "your-dockerhub-username/microservices-frontend:latest"
        ports = ["http"]
        
        # Force pull to get the correct architecture image
        force_pull = false
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