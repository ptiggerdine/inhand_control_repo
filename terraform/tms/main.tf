# source https://github.com/taliesins/terraform-provider-hyperv/blob/master/examples/vm-from-scratch/main.tf
# https://github.com/taliesins/terraform-provider-hyperv/issues/91
terraform {
  required_providers {
    hyperv = {
      version = "1.0.3"
      source  = "registry.terraform.io/taliesins/hyperv"
    }
    # windowsnetwork = {
    #   version = "0.2"
    #   source  = "github.com/claudusd/terraform-windows-network"
    # }
  }
}

provider "hyperv" {
  user     = var.username
  password = var.password
  https    = false
  port     = 5985
}

#Primary disk
resource "hyperv_vhd" "ts_host-vhdx-01" {
  # D:\\Hyper-V\\tms-s-rds\\Virutal Disks\\tms-s-rds-01.vhdx
  path   = "${var.vmpath}\\${var.ts_hostname}\\Virtual Disks\\${var.ts_hostname}-boot.vhdx" #Needs to be absolute path
  source = var.template
}
#secondary disk
resource "hyperv_vhd" "ts_host-vhdx-02" {
  path = "${var.vmpath}\\${var.ts_hostname}\\Virtual Disks\\${var.ts_hostname}-02.vhdx" #Needs to be absolute path
  size = var.ts_vhd_size02
}

resource "hyperv_machine_instance" "ts_host" {
  name                   = var.ts_hostname
  generation             = 1
  processor_count        = 4
  static_memory          = true
  memory_startup_bytes   = var.ts_ram #32Gb
  wait_for_state_timeout = 10
  wait_for_ips_timeout   = 10
  automatic_start_action = "StartIfRunning"
  automatic_start_delay  = 0
  automatic_stop_action  = "Save"
  checkpoint_type        = "Production"
  smart_paging_file_path = "${var.vmpath}\\${var.ts_hostname}\\smartpaging"
  snapshot_file_location = "${var.vmpath}\\${var.ts_hostname}\\snapshots"

  vm_processor {
    expose_virtualization_extensions = true
  }

  integration_services = {
    "Time Synchronization" = false
    "Shutdown"             = true
    "VSS"                  = true
  }

  network_adaptors {
    name         = "lan"
    switch_name  = var.vswitch_name
    wait_for_ips = false
    router_guard = "On"
    dhcp_guard   = "On"
    # turn off SR-IOV since NIC's don't support it.
    allow_teaming = "Off"
    vmq_weight    = 0
    iov_weight    = 0
  }

  hard_disk_drives {
    controller_type           = "Ide"
    path                      = hyperv_vhd.ts_host-vhdx-01.path
    controller_number         = 0
    controller_location       = 0
    override_cache_attributes = "WriteCacheEnabled"
  }

  hard_disk_drives {
    controller_type           = "Ide"
    path                      = hyperv_vhd.ts_host-vhdx-02.path
    controller_number         = 0
    controller_location       = 1
    override_cache_attributes = "WriteCacheEnabled"
  }

  dvd_drives {
    controller_number   = 1
    controller_location = 0
  }
}

output "ips" {
  value = hyperv_machine_instance.ts_host.network_adaptors[0].ip_addresses
}
