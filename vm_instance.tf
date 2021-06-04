resource "google_compute_instance" "vm_desktop" {
  name         = "vm-desktop-01"
  machine_type = "e2-standard-2"
  zone         = "${var.region}-b"
  description  = "desktop test"
  tags         = ["desktop"]

  metadata_startup_script = file("./startup-script.sh")

  boot_disk {
    initialize_params {
      image = "debian-10-buster-v20210512"
    }
  }
  // Network
  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      // Ephemeral IP
      }
  }
}

// Firewall for SSH/RDP ingress connection
resource "google_compute_firewall" "rdp_firewall" {
  name    = "allow-rdp-to-vm-desktop"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports = [ "22" ]
  }

  target_tags = google_compute_instance.vm_desktop.tags

}