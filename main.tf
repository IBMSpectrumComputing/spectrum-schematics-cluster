##############################################################################
# Require terraform 0.9.3 or greater
##############################################################################
terraform {
  required_version = ">= 0.9.3"
}
##############################################################################
# IBM Cloud Provider
##############################################################################
# See the README for details on ways to supply these values
# Configure the IBM Cloud Provider
provider "ibm" {
  bluemix_api_key    = "${var.ibm_bmx_api_key}"
  softlayer_username = "${var.ibm_sl_username}"
  softlayer_api_key  = "${var.ibm_sl_api_key}"
}

# Create an SSH key. The SSH key surfaces in the SoftLayer console under Devices > Manage > SSH Keys.
resource "ibm_compute_ssh_key" "ssh_compute_key" {
  label      = "${var.ssh_key_label}_${var.ibm_sl_username}"
  notes      = "${var.ssh_key_note} ${var.ibm_sl_username}"
  public_key = "${var.ssh_public_key}"
}

# Create bare metal servers with the SSH key.
resource "ibm_compute_bare_metal" "masters" {
  hostname          = "${var.prefix_master}${count.index}"
  domain            = "${var.domain_name}"
  ssh_key_ids       = ["${ibm_compute_ssh_key.ssh_compute_key.id}"]
  os_reference_code = "${var.os_reference}"
  fixed_config_preset = "${var.fixed_config_preset}"
  datacenter        = "${var.datacenter_bare_metal}"
  hourly_billing    = "${var.hourly_billing_master}"
  network_speed     = "${var.network_speed_master}"
  count             = "${var.master_use_bare_metal ? 1 : 0}"
  #user_metadata = "#!/bin/bash\n\ndeclare -i numbercomputes=${var.number_of_compute + var.number_of_compute_bare_metal}\nuseintranet=${var.use_intranet}\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symhead\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nentitlement=${base64encode(var.entitlement)}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n${file("scripts/ibm_spectrum_computing_deploy.sh")}"
  #post_install_script_uri     = "${var.post_install_script_uri}"
  private_network_only        = false

  connection {
    user = "root"
    private_key = "${file(pathexpand("~/.ssh/id_rsa"))}"
    host = "${self.public_ipv4_address}"
  }
  provisioner "local-exec" {
    command = "mkdir -p files; echo \"numbercomputes=${var.number_of_compute + var.number_of_compute_bare_metal}\nuseintranet=${var.use_intranet}\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symhead\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nentitlement=${base64encode(var.entitlement)}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n\" > files/user_metadata.symhead"
  }
  provisioner "file" {
    source = "files/user_metadata.symhead"
    destination = "/root/user_metadata"
  }
  provisioner "file" {
    source = "scripts/ibm_spectrum_computing_deploy.sh"
    destination = "/root/ibm_spectrum_computing_deploy.sh"
  }
  provisioner "remote-exec" {
    inline = "bash /root/ibm_spectrum_computing_deploy.sh"
  }
}

# Create virtual servers with the SSH key.
resource "ibm_compute_vm_instance" "masters" {
  hostname          = "${var.prefix_master}${count.index}"
  domain            = "${var.domain_name}"
  ssh_key_ids       = ["${ibm_compute_ssh_key.ssh_compute_key.id}"]
  os_reference_code = "${var.os_reference}"
  datacenter        = "${var.datacenter}"
  hourly_billing    = "${var.hourly_billing_master}"
  network_speed     = "${var.network_speed_master}"
  cores             = "${var.core_of_master}"
  memory            = "${var.memory_in_mb_master}"
  count             = "${var.master_use_bare_metal ? 0 : 1}"
  user_metadata = "#!/bin/bash\n\ndeclare -i numbercomputes=${var.number_of_compute + var.number_of_compute_bare_metal}\nuseintranet=${var.use_intranet}\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symhead\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nentitlement=${base64encode(var.entitlement)}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n${file("scripts/ibm_spectrum_computing_deploy.sh")}"
  private_network_only        = false
}

resource "ibm_compute_bare_metal" "computes" {
  hostname          = "${var.prefix_compute_bare_metal}${count.index}"
  domain            = "${var.domain_name}"
  ssh_key_ids       = ["${ibm_compute_ssh_key.ssh_compute_key.id}"]
  os_reference_code = "${var.os_reference}"
  fixed_config_preset = "${var.fixed_config_preset}"
  datacenter        = "${var.datacenter_bare_metal}"
  hourly_billing    = "${var.hourly_billing_compute}"
  network_speed     = "${var.network_speed_compute}"
  count             = "${var.number_of_compute_bare_metal}"
  #user_metadata = "#!/bin/bash\n\nuseintranet=false\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symcompute\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nmasterhostnames=${var.prefix_master}0\nmasterprivateipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address_private}\nmasterpublicipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n${file("scripts/ibm_spectrum_computing_deploy.sh")}"
  #post_install_script_uri     = "${var.post_install_script_uri}"
  private_network_only        = false
  connection {
    user = "root"
    private_key = "${file(pathexpand("~/.ssh/id_rsa"))}"
    host = "${self.public_ipv4_address}"
  }
  provisioner "local-exec" {
    command = "mkdir -p files; echo \"useintranet=false\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symcompute\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nmasterhostnames=${var.prefix_master}0\nmasterprivateipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address_private}\nmasterpublicipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n\" > files/user_metadata.symcompute"
  }
  provisioner "file" {
    source = "files/user_metadata.symcompute"
    destination = "/root/user_metadata"
  }
  provisioner "file" {
    source = "scripts/ibm_spectrum_computing_deploy.sh"
    destination = "/root/ibm_spectrum_computing_deploy.sh"
  }
  provisioner "remote-exec" {
    inline = "bash /root/ibm_spectrum_computing_deploy.sh"
  }
}

resource "ibm_compute_vm_instance" "computes" {
  hostname          = "${var.prefix_compute}${count.index}"
  domain            = "${var.domain_name}"
  ssh_key_ids       = ["${ibm_compute_ssh_key.ssh_compute_key.id}"]
  os_reference_code = "${var.os_reference}"
  datacenter        = "${var.datacenter}"
  hourly_billing    = "${var.hourly_billing_compute}"
  network_speed     = "${var.network_speed_compute}"
  cores             = "${var.core_of_compute}"
  memory            = "${var.memory_in_mb_compute}"
  count             = "${var.number_of_compute}"
  user_metadata = "#!/bin/bash\n\nuseintranet=${var.use_intranet}\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symcompute\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nmasterhostnames=${var.prefix_master}0\nmasterprivateipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address_private}\nmasterpublicipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n${file("scripts/ibm_spectrum_computing_deploy.sh")}"
  private_network_only        = "${var.use_intranet ? true : false}"
}

resource "ibm_compute_vm_instance" "dehosts" {
  hostname          = "${var.prefix_dehost}${count.index}"
  domain            = "${var.domain_name}"
  ssh_key_ids       = ["${ibm_compute_ssh_key.ssh_compute_key.id}"]
  os_reference_code = "${var.os_reference}"
  datacenter        = "${var.datacenter}"
  hourly_billing    = "${var.hourly_billing_compute}"
  network_speed     = "${var.network_speed_compute}"
  cores             = "${var.core_of_compute}"
  memory            = "${var.memory_in_mb_compute}"
  count             = "${var.number_of_dehost}"
  user_metadata = "#!/bin/bash\n\nuseintranet=${var.use_intranet}\ndomain=${var.domain_name}\nproduct=${var.product}\nversion=${var.version}\nrole=symde\nclusteradmin=${var.cluster_admin}\nclustername=${var.cluster_name}\nmasterhostnames=${var.prefix_master}0\nmasterprivateipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address_private}\nmasterpublicipaddress=${ibm_compute_vm_instance.masters.0.ipv4_address}\nfunctionsfile=${replace(var.post_install_script_uri, basename(var.post_install_script_uri), var.product)}.sh\n${file("scripts/ibm_spectrum_computing_deploy.sh")}"
  private_network_only        = false
}

##############################################################################
# Variables
##############################################################################
variable ibm_bmx_api_key {
  description = "Your Bluemix API Key."
}
variable ibm_sl_username {
  description = "Your Softlayer username."
}
variable ibm_sl_api_key {
  description = "Your Softlayer API Key."
}
variable datacenter {
  default = "dal12"
  description = "The datacenter to create resources in."
}
variable datacenter_bare_metal {
  default = "wdc04"
  description = "The datacenter to create baremetal resources in."
}
variable entitlement {
  default = <<EOF
ego_base   3.6   dd/mm/yyyy   ()   ()   ()   ****************************************
sym_advanced_edition   7.2   dd/mm/yyyy   ()   ()   ()   ****************************************
EOF
  description = "your entitlement file content here"
}
variable ssh_public_key {
  description = "Your public SSH key to access your cluster hosts."
}
variable ssh_key_label {
  default = "ssh_compute_key"
  description = "A label for the SSH key that gets created."
}
variable ssh_key_note {
  default = "ssh key for cluster hosts"
  description = "used to login to softlayer sessions"
}
variable product {
  default = "symphony"
  description = "spectrum computing product to install"
}
variable version {
  default = "latest"
  description = "spectrum computing product version"
}
variable role {
  default = "symcompute"
  description = "node role of the product"
}
variable cluster_admin {
  default = "egoadmin"
  description = "specify cluster admin account"
}
variable cluster_name {
  default = "symcluster"
  description = "specify cluster name"
}
variable domain_name {
  default = "domain.com"
  description = "specify dns domain name"
}
variable prefix_master {
  default = "master"
  description = "specify host name for master server"
}
variable prefix_compute {
  default = "compute"
  description = "specify hostname prefix for compute nodes"
}
variable prefix_compute_bare_metal {
  default = "bmcompute"
  description = "specify hostname prefix for bare metal compute nodes"
}
variable prefix_dehost {
  default = "dehost"
  description = "specify hostname prefix for development nodes"
}
variable number_of_compute {
  default = 2
  description = "specify number of compute nodes to create"
}
variable number_of_compute_bare_metal {
  default = 0
  description = "specify number of bare metal compute nodes to create"
}
variable number_of_dehost {
  default = 1
  description = "specify number of development nodes to create"
}
variable network_speed_master {
  default = 1000
  description = "specify network speed of master server"
}
variable network_speed_compute {
  default = 1000
  description = "specify network speed of compute server"
}
variable core_of_master {
  default = 2
  description = "specify core number of master server"
}
variable core_of_compute {
  default = 1
  description = "specify core number of compute server"
}
variable memory_in_mb_master {
  default = 8192
  description = "specify memory of master server"
}
variable memory_in_mb_compute {
  default = 4096
  description = "specify memory of compute server"
}
variable os_reference {
  default = "CENTOS_7_64"
  description = "specify which OS to use for your cluster"
}
variable master_use_bare_metal {
  default = "false"
  description = "create bare metal masters if ture, otherwise create vm masters"
}
variable fixed_config_preset {
  default = "S1270_32GB_1X1TBSATA_NORAID"
  description = "softlayer bare metal hardware configuration"
}
variable use_intranet {
  default = "true"
  description = "specify if to resolve hostnames with intranet ip addresses"
}
variable hourly_billing_master {
  default = "true"
  description = "hourly change if true or monthly if false"
}
variable hourly_billing_compute {
  default = "true"
  description = "hourly change if true or monthly if false"
}
variable post_install_script_uri {
  default = "https://raw.githubusercontent.com/IBMSpectrumComputing/spectrum-schematics-cluster/master/scripts/ibm_spectrum_computing_deploy.sh"
  description = "uri to the deployment script"
}

##############################################################################
# Outputs
##############################################################################
output "symphony_cluster_master_ip" {
  value = "${ibm_compute_vm_instance.masters.0.ipv4_address}"
}
output "symphony_cluster_dehost_ip" {
  value = "${ibm_compute_vm_instance.dehosts.0.ipv4_address}"
}
output "symphony_cluster_web_interface" {
  value = "https://${ibm_compute_vm_instance.masters.0.ipv4_address}:8443/platform"
}
