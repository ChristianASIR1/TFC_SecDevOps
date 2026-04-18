# 🏗️ INFRAESTRUCTURA TERRAFORM - TFC SecDevOps v2

## [cite_start]CÓDIGO PRINCIPAL (main.tf) [cite: 7]

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# [cite_start]RED PRIVADA (LAN) [cite: 16]
resource "libvirt_network" "lan_secdevops" {
  name      = "lan-secdevops"
  mode      = "none"
  addresses = ["10.0.0.0/24"]
  autostart = true
  dhcp { enabled = false }
}

# [cite_start]CLOUD-INIT DISKS [cite: 7]
resource "libvirt_cloudinit_disk" "commoninit_wazuh_v2" {
  name      = "commoninit_wazuh_v2.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", { vm_hostname = "wazuh-server" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = "10.0.0.10" })
}

resource "libvirt_cloudinit_disk" "commoninit_podman_v2" {
  name      = "commoninit_podman_v2.iso"
  [cite_start]pool      = "default" [cite: 8]
  user_data = templatefile("${path.module}/cloud_init.cfg", { vm_hostname = "podman-node" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = "10.0.0.20" })
}

# DOMINIOS (MÁQUINAS VIRTUALES)
resource "libvirt_domain" "wazuh_server" {
  name   = "wazuh-server"
  [cite_start]memory = "6144" [cite: 12]
  [cite_start]vcpu   = 2 [cite: 13]
  cloudinit = libvirt_cloudinit_disk.commoninit_wazuh_v2.id
  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:00:10"
  }
  disk { volume_id = libvirt_volume.wazuh_disk_v2.id }
}

resource "libvirt_domain" "podman_node" {
  name   = "podman-node"
  [cite_start]memory = "4096" [cite: 14]
  vcpu   = 2
  cloudinit = libvirt_cloudinit_disk.commoninit_podman_v2.id
  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:00:20"
  }
  disk { volume_id = libvirt_volume.podman_disk_v2.id }
}

resource "libvirt_domain" "opnsense_firewall" {
  name   = "opnsense-firewall"
  [cite_start]memory = "2048" [cite: 11]
  vcpu   = 2
  network_interface { network_name = "default" }
  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:02:54"
  }
  disk { volume_id = libvirt_volume.opnsense_disk_v2.id }
}

---

## [cite_start]CONFIGURACIÓN CLOUD-INIT (cloud_init.cfg) [cite: 5]

#cloud-config
users:
  - name: walter
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1Zj4Zj9BfTzob0mAGz14KuNtOV9mVpcyrPQWuzhaOz walter@thinkpad-lab

ssh_pwauth: false
package_update: true
package_upgrade: true
hostname: ${vm_hostname}

---

## [cite_start]CONFIGURACIÓN DE RED (network_config.cfg) [cite: 17]

version: 2
ethernets:
  ens3:
    dhcp4: false
    addresses:
      - ${ip_address}/24
    routes:
      - to: default
        via: 10.0.0.254
    nameservers:
      addresses: [9.9.9.9, 1.1.1.2]

---

## [cite_start]PLANTILLA DE INVENTARIO (inventario.tftpl) [cite: 6]

[wazuh]
wazuh-server ansible_host=10.0.0.10 ansible_user=walter

[podman]
podman-node ansible_host=10.0.0.20 ansible_user=walter

[redteam]
redteam-node ansible_host=${redteam_ip} ansible_user=walter
