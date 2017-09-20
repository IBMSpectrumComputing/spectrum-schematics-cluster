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
  label      = "${var.ssh_key_label}"
  notes      = "${var.ssh_key_note}"
  public_key = "${var.ssh_public_key}"
}

# Create a virtual server with the SSH key.
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
  count             = 1
  user_metadata = "{\"useintranet\": \"${var.use_intranet}\", \"domain\": \"${var.domain_name}\", \"product\": \"${var.product}\", \"version\": \"${var.version}\", \"role\":\"symhead\",\"clusteradmin\":\"${var.cluster_admin}\", \"clustername\": \"${var.cluster_name}\",\"entitlement\":\"${base64encode(join(var.seporator,var.entitlement))}\"}"
  post_install_script_uri     = "${var.post_install_script_uri}"
  private_network_only        = false
}

resource "ibm_compute_vm_instance" "slaves" {
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
  user_metadata = "{\"useintranet\": \"${var.use_intranet}\", \"domain\": \"${var.domain_name}\", \"product\": \"${var.product}\", \"version\": \"${var.version}\", \"role\":\"symcompute\",\"clusteradmin\":\"${var.cluster_admin}\", \"clustername\": \"${var.cluster_name}\", \"masterhostnames\":\"${ibm_compute_vm_instance.masters.0.hostname}\", \"masteripaddress\":\"${var.use_intranet ? ibm_compute_vm_instance.masters.0.ipv4_address_private : ibm_compute_vm_instance.masters.0.ipv4_address}\"}"
  post_install_script_uri     = "${var.post_install_script_uri}"
  private_network_only        = false
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
  user_metadata = "{\"useintranet\": \"${var.use_intranet}\", \"domain\": \"${var.domain_name}\", \"product\": \"${var.product}\", \"version\": \"${var.version}\", \"role\":\"symde\",\"clusteradmin\":\"${var.cluster_admin}\", \"clustername\": \"${var.cluster_name}\", \"masterhostnames\":\"${ibm_compute_vm_instance.masters.0.hostname}\", \"masteripaddress\":\"${var.use_intranet ? ibm_compute_vm_instance.masters.0.ipv4_address_private : ibm_compute_vm_instance.masters.0.ipv4_address}\"}"
  post_install_script_uri     = "${var.post_install_script_uri}"
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
  default = "tor01"
  description = "The datacenter to create resources in."
}
variable seporator {
  default = "\n"
  description = "join entitlement"
}
variable entitlement {
  type = "list"
  default = ["ego_base   3.6   dd/mm/yyyy   ()   ()   ()   ****************************************", "sym_advanced_edition   7.2   dd/mm/yyyy   ()   ()   ()   ****************************************"]
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
variable prefix_dehost {
  default = "dehost"
  description = "specify hostname prefix for development nodes"
}
variable number_of_compute {
  default = 2
  description = "specify number of compute nodes to create"
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
  default = "CENTOS_LATEST"
  description = "specify which OS to use for your cluster"
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
