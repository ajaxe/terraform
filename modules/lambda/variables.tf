variable "lambda_zip_path" {
}
variable "environment" {
  type = string
}
variable "app_name" {
  type = string
}
variable "function_name" {
  type = string
}
variable "function_handler" {
  type = string
}
variable "deployment_package_key" {
  type = string
}
variable "deployment_key_prefix" {
  type    = string
  default = "tf"
}
variable "deployment_s3_bucket" {
  type    = string
  default = "lambda-deployment.apogee-dev.com"
}
variable "memory_size" {
  type    = number
  default = 512
}
variable "lambda_timeout" {
  type    = number
  default = 30
}
variable "runtime" {
  type    = string
  default = "dotnetcore3.1"
}
variable "env_variables" {
  default = {}
}
variable "lambda_add_on_policy" {
  type    = string
  default = ""
}
