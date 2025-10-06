## Copyright (c) 2021, Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# This Terraform script provisions a VCN and a compute instance 

# ---- use variables defined in terraform.tf vars or bash profile file

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "compartment_ocid" {}
variable "region" {}

#--- provider
provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
}

variable "tenantname" {
  default = "CLOUDACCOUNT/TENANTID"
}


# ------ Create a new VCN
variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

resource "oci_core_virtual_network" "tf-vcn" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "vs-net"
  dns_label      = "vsnet"
}

###--- Create a new NAT Gateway
resource "oci_core_nat_gateway" "terraform-NAT-gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "vsnet-NAT-gateway"
  vcn_id         = oci_core_virtual_network.tf-vcn.id
}

# ------ Create a new Internet Gateway
resource "oci_core_internet_gateway" "terraform-ig" {
  compartment_id = var.compartment_ocid
  display_name   = "terraform-internet-gateway"
  vcn_id         = oci_core_virtual_network.tf-vcn.id
}

# ------ Create a new Route Table
resource "oci_core_route_table" "terraform-rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tf-vcn.id
  display_name   = "public-sn-route-table"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.terraform-ig.id
  }
}

resource "oci_core_route_table" "terraform-rt2" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tf-vcn.id
  display_name   = "private-sn-route-table2"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.terraform-NAT-gateway.id
  }
}

# ------ Create a public subnet in the new VCN
resource "oci_core_subnet" "terraform-public-subnet1" {
  cidr_block      = "10.0.1.0/24"
  display_name    = "public-subnet1"
  dns_label       = "subnet1"
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_virtual_network.tf-vcn.id
  route_table_id  = oci_core_route_table.terraform-rt.id
  dhcp_options_id = oci_core_virtual_network.tf-vcn.default_dhcp_options_id
}

####Create a private subnet  in the new VCN
resource "oci_core_subnet" "terraform-private-subnet1" {
  cidr_block      = "10.0.0.0/24"
  display_name    = "private-subnet1"
  dns_label       = "subnet2"
  prohibit_public_ip_on_vnic = "true"
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_virtual_network.tf-vcn.id
  route_table_id  = oci_core_route_table.terraform-rt2.id
  dhcp_options_id = oci_core_virtual_network.tf-vcn.default_dhcp_options_id
}


## Create compute instance

variable "ssh_public_key" {
    default ="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2kUYON3kclgdFTQDqsU4Blq50VCR1KPFu6ld6BJnjVgG8LoJACycTRv3KdnE7bIFwIRucEVfL2m5dWZWNQX6BygZiQnMXqnN2Gth131kFM/ObBAB6dPS5LM8vX/L+Lm6CMN41AfD8/fLdMlrtDuA9//rQyP8FJflcg+hbV3AbnDE4sr5fSkvGJrO/PHIZleUYm+5XQDToioxto+tbS2rt0jz5C8R6sh5Z+/btAku+iTVxkmB7l+AUThW13CJ7jVVvocjSdw5WIMfZaFGr0FUnZ8oq8ymd7zWb3PxiqLomBqW8EpKVGeMiT1+lQ0PMl2ygjtKn7Sq4UmSWE1WtOHVF lab_user04@2575086beff2"
}

data "oci_identity_availability_domains" "ADs" {
compartment_id = "${var.tenancy_ocid}"
}

variable "instance_shape" {
  default = "VM.Standard.E4.Flex"
}

variable "availability_domain" {
  default = 3
}

variable "instance_image_ocid" {
  default =  "Enter the Image OCID as given in the instructions"
}

resource "oci_core_instance" "compute_instance" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain -1],"name")}"
  compartment_id      = var.compartment_ocid
  display_name        = "vs-webserver"
  shape               = var.instance_shape
  fault_domain        = "FAULT-DOMAIN-1"

  shape_config {
      ocpus         = 2
      memory_in_gbs = 16
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key 
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.terraform-public-subnet1.id
    display_name              = "primaryvnic"
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label      = "vs-webserver"
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = "50"
  }

} 

#variable "bucket_name" {
#  default = "vs-bucket"
#}


####Creation of a new bucket
#resource "oci_objectstorage_bucket" "terraform-bucket" {
#  compartment_id = var.compartment_ocid
#  namespace      = var.tenantname
# name           = "vs-bucket"
#  access_type    = "NoPublicAccess"
#}