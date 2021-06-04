// Do not chage this file

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 1
  description = "number of gke nodes"
}

variable "gke_name" {
  description = "GKE cluster name"
}

variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

variable "credentials_file" {
 description = "credentials json file"
} 