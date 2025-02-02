variable "environment" {

}
variable "aws_region" {
  default = "us-east-1"
}
variable "app_name" {
  default = "route53updater"
}
variable "lambda_folder" {

}
variable "hosted_zone_id" {

}
variable "pre_shared_key" {

}
variable "memory_size" {
  default = 128
}
variable "runtime" {
  default = "provided.al2023"
}