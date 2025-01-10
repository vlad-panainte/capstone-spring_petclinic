terraform {
  required_version = "~> 1.10.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.1"
    }
  }
  backend "gcs" {
    bucket = "vpanainte-tfstate-deployment"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.main_cluster.endpoint}"
  token                  = data.google_client_config.default_config.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.main_cluster.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default_config" {}

data "google_container_cluster" "main_cluster" {
  name = var.gke_name
}

data "google_artifact_registry_docker_image" "spring_petclinic" {
  location      = var.region
  repository_id = var.artifact_repository_id
  image_name    = var.image_name
}

data "google_sql_database_instance" "spring_petclinic" {
  name = var.sql_database_name
}

resource "kubernetes_secret_v1" "service_account" {
  metadata {
    name = "service-account"
  }

  data = {
    "service_account.json" = file(var.gke_deployment_secret_service_account)
  }
}

resource "kubernetes_secret_v1" "database_credentials" {
  metadata {
    name = "database-credentials"
  }

  data = {
    "username" = var.sql_user_name
    "password" = var.sql_user_password
  }
}

resource "kubernetes_deployment_v1" "spring_petclinic" {
  metadata {
    name = var.gke_deployment_name
  }

  spec {
    selector {
      match_labels = {
        app = var.gke_deployment_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.gke_deployment_name
        }
      }

      spec {
        container {
          image = data.google_artifact_registry_docker_image.spring_petclinic.self_link
          name  = var.gke_deployment_name

          port {
            container_port = 8080
          }

          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "mysql"
          }

          env {
            name  = "SPRING_DATASOURCE_URL"
            value = "jdbc:mysql://127.0.0.1:3306/petclinic"
          }

          env {
            name = "SPRING_DATASOURCE_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.database_credentials.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.database_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "700m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }

            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }

        container {
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.2-alpine"
          name  = "cloud-sql-proxy"

          args = [data.google_sql_database_instance.spring_petclinic.connection_name, "--port=3306", "--credentials-file=/secrets/cloudsql/service_account.json", "--structured-logs"]

          resources {
            requests = {
              cpu    = "100m"
              memory = "48Mi"
            }
          }

          volume_mount {
            name       = "service-account"
            mount_path = "/secrets/cloudsql"
            read_only  = true
          }
        }

        volume {
          name = "service-account"
          secret {
            secret_name = kubernetes_secret_v1.service_account.metadata[0].name
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "kubernetes.io/arch"
          operator = "Equal"
          value    = "amd64"
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "spring_petclinic" {
  metadata {
    name = "spring-petclinic-horizontal-autoscaler"
  }

  spec {
    min_replicas = 1
    max_replicas = 3

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = var.gke_deployment_name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "75"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "spring_petclinic" {
  metadata {
    name = "spring-petclinic-loadbalancer"
  }

  spec {
    selector = {
      app = kubernetes_deployment_v1.spring_petclinic.spec[0].selector[0].match_labels.app
    }

    port {
      port        = 80
      target_port = kubernetes_deployment_v1.spring_petclinic.spec[0].template[0].spec[0].container[0].port[0].container_port
    }

    type = "LoadBalancer"
  }
}

output "gke_load_balancer_ip" {
  value       = kubernetes_service_v1.spring_petclinic.status[0].load_balancer[0].ingress[0].ip
  description = "GKE Load Balancer public IP"
}
