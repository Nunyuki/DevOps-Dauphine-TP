# Créer un dépôt Artifact Registry avec commme repository_id : website-tools
resource "google_artifact_registry_repository" "website-tools" {
  repository_id = "website-tools"
  location      = "us-central1"
  format        = "DOCKER"
}

# Les APIs nécessaires au bon fonctionnement du projet
resource "google_project_service" "ressource_manager" {
    service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "ressource_usage" {
    service = "serviceusage.googleapis.com"
    depends_on = [ google_project_service.ressource_manager ]
}

resource "google_project_service" "artifact" {
    service = "artifactregistry.googleapis.com"
    depends_on = [ google_project_service.ressource_manager ]
}

resource "google_project_service" "cloud_build" {
  service = "cloudbuild.googleapis.com"
  depends_on = [ google_project_service.ressource_manager ]
}

resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
  depends_on = [ google_project_service.ressource_manager ]
}

# SQL Database
resource "google_sql_database" "database" {
  name     = "wordpress"
  instance = "main-instance"
}

# SQL User
resource "google_sql_user" "wordpress" {
   name     = "wordpress"
   instance = "main-instance"
   password = "ilovedevops"
}

data "google_iam_policy" "noauth" {
   binding {
      role = "roles/run.invoker"
      members = [
         "allUsers",
      ]
   }
}

# Définition de la politique IAM pour Cloud Run
resource "google_cloud_run_service_iam_policy" "noauth" {
  location = "us-central1" 
  project  = "vital-charger-424406-u2" 
  service  = "wordpress-service"

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_service" "wordpress" { 
    name = "wordpress-service"
    location = "us-central1" 
    template { 
        spec { 
            containers { 
                image = "us-central1-docker.pkg.dev/vital-charger-424406-u2/website-tools/my-wordpress" 
                ports { 
                    container_port = 80 
                } 
            } 
        } 
    } 
    traffic { 
        percent = 100 
        latest_revision = true 
    } 
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.18"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}


data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
   name     = "gke-dauphine"
   location = "us-central1-a"
}

provider "kubernetes" {
  host                   = data.google_container_cluster.my_cluster.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}


# Créer un secret pour le mot de passe MySQL
resource "kubernetes_secret" "mysql_password" {
  metadata {
    name      = "mysql-password"
    namespace = "default"
  }

  data = {
    password = base64encode("your-mysql-password")
  }
}

# Déploiement de MySQL
resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = "default"
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mysql"
      }
    }
    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:5.7"
          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_password.metadata.0.name
                key  = "password"
              }
            }
          }
        }
      }
    }
  }
}

# Service MySQL
resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = "default"
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }
  }
}

# Déploiement de WordPress
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = "default"
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "wordpress"
      }
    }
    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"
          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql:3306"
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = "root"
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_password.metadata.0.name
                key  = "password"
              }
            }
          }
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Service WordPress
resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = "default"
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

