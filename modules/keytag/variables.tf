variable "aws_region" {
  type = string
}
variable "environment" {
  type = string
}
variable "app_name" {
  type    = string
  default = "keytag"
}
variable "runtime" {
  type    = string
  default = "dotnetcore3.1"
}
variable "webapp_folder" {
  type = string
}
