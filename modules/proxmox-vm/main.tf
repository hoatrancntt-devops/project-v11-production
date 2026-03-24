# ============================================
# modules/proxmox-vm/main.tf
# Provider: bpg/proxmox
# ============================================

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "cloud-init-v11.yml"
    data = templatefile("${path.module}/cloud-init.cfg", {
      hostname           = var.vm_hostname
      ssh_public_key     = var.ssh_public_key
      db_password        = var.db_password
      wg_private_key     = var.wg_private_key_proxmox
      wg_peer_public_key = var.wg_public_key_ec2
      ec2_public_ip      = var.ec2_public_ip
    })
  }
}

resource "proxmox_virtual_environment_vm" "db_server" {
  name      = var.vm_hostname
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  clone {
    vm_id = var.template_vm_id
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }
    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  operating_system {
    type = "l26"
  }

  started = true
}
