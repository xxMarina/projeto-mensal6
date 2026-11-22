resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false

  provisioner "local-exec" {
    when    = destroy
    command = "gcloud compute networks peerings delete servicenetworking-googleapis-com --network=${self.name} --project=${self.project} --quiet 2>/dev/null || true"
  }

  depends_on = [google_project_service.enabled_apis]
}

resource "google_compute_subnetwork" "publica" {
  name          = "subnet-public"
  ip_cidr_range = var.subnet_public_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "privada" {
  name                     = "subnet-private"
  ip_cidr_range            = var.subnet_private_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "conector" {
  name          = "subnet-vpc-connector"
  ip_cidr_range = var.subnet_connector_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_router" "router" {
  name    = "marmitech-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat_ip" {
  name         = "marmitech-nat-ip"
  region       = var.region
  address_type = "EXTERNAL"
  labels       = var.labels

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.enabled_apis]
}

resource "google_compute_router_nat" "nat" {
  name                               = "marmitech-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.privada.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "marmitech-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_project_service.enabled_apis]
}

resource "google_vpc_access_connector" "connector" {
  name          = "marmitech-vpc-connector"
  region        = var.region
  min_instances = 2
  max_instances = 3

  subnet {
    name = google_compute_subnetwork.conector.name
  }

  depends_on = [google_project_service.enabled_apis]
}
