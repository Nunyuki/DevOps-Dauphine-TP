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
