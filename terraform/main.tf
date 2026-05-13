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

# ================================================
# 1. CLOUD-INIT #
# ================================================

# Wazuh#
resource "libvirt_cloudinit_disk" "commoninit_wazuh_v2" {
  name		= "commoninit_wazuh_v2.iso"
  pool		= "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", { vm_hostname = "wazuh-server" })
  network_config = templatefile("${path.module}/network_config.cfg", { 
    ip_address = "10.0.0.10",
  })
}

# Podman #
resource "libvirt_cloudinit_disk" "commoninit_podman_v2" {
  name      = "commoninit_podman_v2.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", { vm_hostname = "podman-node" })
  network_config = templatefile("${path.module}/network_config.cfg", {
    ip_address = "10.0.0.20",
  })
}

# Red_Team #
resource "libvirt_cloudinit_disk" "commoninit_redteam_v2" {
  name      = "commoninit_redteam_v2.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", { vm_hostname = "redteam-node" })
}


# ================================================     
# 2. Discos/Imagenes base #
# ================================================

# OPNsense#
resource "libvirt_volume" "opnsense_disk" {
  name   = "opnsense_v26_v1.qcow2"
  pool   = "default"
  source = "./os_images/opnsense_v2618.qcow2"
  format = "qcow2"
}

# Imagen base para modificar tamaño #

resource "libvirt_volume" "ubuntu_base_image" {
  name   = "ubuntu-24-04-base"
  pool   = "default"
  source = "./os_images/ubuntu-24.04-base.img"
}


# Wazuh #
resource "libvirt_volume" "wazuh_disk_v2" {
  name   = "wazuh-disk-v2.qcow2"
  pool   = "default"
  base_volume_id = libvirt_volume.ubuntu_base_image.id
  size           = 53687091200
}

# Podman#
resource "libvirt_volume" "podman_disk_v2" {
  name   = "podman-disk-v2.qcow2"
  pool   = "default"
  source = "${path.module}/os_images/ubuntu-24.04-base.img"
  format = "qcow2"
}

# Red Team #
resource "libvirt_volume" "redteam_disk_v2" {
  name   = "redteam-disk-v2.qcow2"
  pool   = "default"
  source = "${path.module}/os_images/ubuntu-24.04-base.img"
  format = "qcow2"
}


# ==========================================
# 3. PARCHE PERMISOS
# ==========================================


resource "null_resource" "fix_permissions_v2" {
  triggers = {
    opnsense_id = libvirt_volume.opnsense_disk.id
    wazuh_id    = libvirt_volume.wazuh_disk_v2.id
    podman_id   = libvirt_volume.podman_disk_v2.id
    redteam_id  = libvirt_volume.redteam_disk_v2.id
  } 
  depends_on = [
    libvirt_volume.wazuh_disk_v2,
    libvirt_volume.podman_disk_v2,
    libvirt_volume.opnsense_disk,
    libvirt_volume.redteam_disk_v2,
    libvirt_cloudinit_disk.commoninit_wazuh_v2,
    libvirt_cloudinit_disk.commoninit_podman_v2,
    libvirt_cloudinit_disk.commoninit_redteam_v2
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sudo chown libvirt-qemu:kvm \
        /var/lib/libvirt/images/wazuh-disk-v2.qcow2 \
        /var/lib/libvirt/images/commoninit_wazuh_v2.iso \
        /var/lib/libvirt/images/podman-disk-v2.qcow2 \
        /var/lib/libvirt/images/commoninit_podman_v2.iso \
        /var/lib/libvirt/images/opnsense_v2618.qcow2 \
        /var/lib/libvirt/images/redteam-disk-v2.qcow2 \
        /var/lib/libvirt/images/commoninit_redteam_v2.iso
    EOT
  }
}

# ==========================================
# 4. MÁQUINAS VIRTUALES / RECURSOS
# ==========================================


##############  OPNsense Firewall #############################

resource "libvirt_domain" "opnsense_firewall" {
  name   = "opnsense-firewall"
  memory = "2048"
  vcpu   = 2

  disk { volume_id = libvirt_volume.opnsense_disk.id }
  depends_on = [null_resource.fix_permissions_v2]

	# WAN #
  network_interface {
    network_name = "default"
    mac          = "52:54:00:00:00:FF"
    wait_for_lease = false
  }
	# LAN #
  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:02:54"
    wait_for_lease = false
  }
	# Acceso por puerto serie a la MV #
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}


######################     Wazuh Monitorización    ###########################

resource "libvirt_domain" "wazuh_server" {
  name   = "wazuh-server"
  memory = "6144"
  vcpu   = 2
  
  depends_on = [null_resource.fix_permissions_v2]
  cloudinit = libvirt_cloudinit_disk.commoninit_wazuh_v2.id
  
  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:00:10"
    wait_for_lease = false
  }

  disk { volume_id = libvirt_volume.wazuh_disk_v2.id }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

#####################      Podman / DVWA Victima      ###########################

resource "libvirt_domain" "podman_node" {
  name   = "podman-node"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit_podman_v2.id
  depends_on = [null_resource.fix_permissions_v2]

  network_interface {
    network_name = libvirt_network.lan_secdevops.name
    mac          = "52:54:00:00:00:20"
    wait_for_lease = false
  }

  disk { volume_id = libvirt_volume.podman_disk_v2.id }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

####################   Red-Team Atacante      ########################

resource "libvirt_domain" "redteam_node" {
  name   = "redteam-node"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit_redteam_v2.id
  depends_on = [null_resource.fix_permissions_v2]

  network_interface {
    network_name   = "default"
    mac            = "52:54:00:0A:7A:CC"
    wait_for_lease = true
  }

  disk { volume_id = libvirt_volume.redteam_disk_v2.id }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}


# ==========================================
# 5. RED PRIVADA SECDEVOPS (LAN)
# ==========================================

resource "libvirt_network" "lan_secdevops" {
  name      = "lan-secdevops"
  mode      = "none"
  addresses = ["10.0.0.0/24"]
  autostart = true
  dhcp { enabled = false }
}


# ==========================================
# 6. INVENTARIO DE HOSTS PARA ANSIBLE
# ==========================================

resource "local_file" "ansible_inventory" {
 # Entrada:
 content = templatefile("${path.module}/inventario.tftpl", {
    # Asignacion de la variable:
    redteam_ip = try(libvirt_domain.redteam_node.network_interface[0].addresses[0],"IP desconocida")
  })
# Salida:
  filename = "${path.module}/../ansible/hosts.ini"
}

# ==========================================
# 7. EXTRACCIÓN DE VARIABLES (OUTPUTS)
# ==========================================

output "redteam_ip" {
  description = "IP asignada dinámicamente al nodo Red Team"
  value       = try(libvirt_domain.redteam_node.network_interface[0].addresses[0], "IP desconocida")
}
