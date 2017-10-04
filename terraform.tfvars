###########################################################
# required variables
# here you identify yourself to IBM bluemix and SoftLayer
###########################################################
# Your Bluemix api key
ibm_bmx_api_key = ""
# Your Softlayer username and api key
ibm_sl_username = ""
ibm_sl_api_key = ""
 
## (optional)the datacenter to create vm resources in
## datacenter = "dal12"
## (optional)the datacenter to create bare metal resources in
## datacenter_bare_metal = "tor01"
## (optional)choose charge method, hourly for true and monthly for false
## hourly_billing_master = true
## hourly_billing_compute = true

###########################################################
# required variable ssh_public_key
# here you specify your ssh fingerprint to access servers
###########################################################
# Your public SSH key to access your cluster hosts
ssh_public_key = ""

## (optional)	label for your SSH key
## ssh_key_label = "ssh_compute_key"
## (optional)	description for your SSH key
## ssh_key_note = "ssh key for cluster hosts"

###########################################################
# required variable entitlement
# here you specify your entitlement for the product
###########################################################
entitlement = ""

## (optional)	spectrum computing product to install
## product = "symphony"
## (optional)	spectrum computing product version
## version = "latest"

## (optional)	uri to the deployment script
## post_install_script_uri = "https://raw.githubusercontent.com/IBMSpectrumComputing/spectrum-schematics-cluster/master/scripts/ibm_spectrum_computing_deploy.sh"
## (optional)	specify cluster admin account
## cluster_admin = "egoadmin"
## (optional)	specify cluster name, no space allowed
## cluster_name = "mycluster"

## (optional)	specify OS to use for your cluster
## os_reference = "CENTOS_7_64"
## (optional)	specify dns domain name
## domain_name = "domain.com"
## (optional)	specify host name prefix for master/compute/development nodes
## prefix_master = "master"
## prefix_compute = "compute"
## prefix_dehost = "dehost"

## (optional)	specify number of compute nodes to create
## number_of_compute = 2
## (optional)	specify number of development nodes to create
## number_of_dehost = 1
## (optional)	specify network speed for master and compute nodes
## network_speed_master =1000
## network_speed_compute = 1000
## (optional)	specify cores of master and compute nodes
## core_of_master = 2
## core_of_compute = 1
## (optional)	specify memory of master and compute nodes
## memory_in_mb_master = 8192
## memory_in_mb_compute = 4096

#######################################################################
## for development, do not use
########################################################################
## (optional) specify if to resolve hostnames with intranet ip addresses
## use_intranet = true
## (optional) create baremetal masters if ture, otherwise create vm masters
## master_use_bare_metal = false
## (optional)	specify OS to use for your bare metal nodes
## os_reference_bare_metal = "UBUNTU_16_64"
## (optional) baremetal preset configuration, gpu configruations include
## D2620_128GB_2X1TB_SATA_RAID_1_M60_GPU1, D2690V4_128GB_2X4TB_SATA_RAID_1_K2_GPU2
## D2620V4_128GB_2X800GB_SSD_RAID_1_K80_GPU2, D2690_256GB_2X4TB_SATA_RAID1_2XM60_GPU_RAID_1
## fixed_config_preset = "S1270_32GB_2X960GBSSD_NORAID"
## (optional)	specify number of bare metal compute nodes to create
## number_of_compute_bare_metal = 0
## (optional) specify hostname prefix for bare metal compute nodes
## prefix_compute_bare_metal = "bmcompute"
## {optional) your private SSH key to remote execute on bare metal machines
## ssh_private_key = <<EOF
## multiple line supported
## past your ssh private key here
## EOF
