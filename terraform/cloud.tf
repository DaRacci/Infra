data "digitalocean_droplet" "chomp" {
  name = "chomp"
}

resource "digitalocean_firewall" "chomp_firewall" {
  name = "chomp"

  droplet_ids = [data.digitalocean_droplet.chomp.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = data.sops_file.secrets.data["IPS"]
  }

  inbound_rule {
    protocol   = "tcp"
    port_range = "80"
  }

  inbound_rule {
    protocol   = "tcp"
    port_range = "443"
  }

  inbound_rule {
    protocol   = "udp"
    port_range = "443"
  }

  inbound_rule {
    protocol   = "tcp"
    port_range = "3478"
  }

  inbound_rule {
    protocol   = "udp"
    port_range = "3478"
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = data.sops_file.secrets.data["IPS"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8443"
    source_addresses = data.sops_file.secrets.data["IPS"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = data.sops_file.secrets.data["IPS"]
  }
}
