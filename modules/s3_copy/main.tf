locals {
  clean_key_prefix = trimsuffix(var.key_prefix, "/")
  mime_types       = jsondecode(file("${path.module}/mime.json"))
}
data "aws_s3_bucket" "selected" {
  bucket = var.deploy_bucket
}
resource "aws_s3_object" "object" {
  for_each     = fileset(var.deploy_source, "**")
  bucket       = data.aws_s3_bucket.selected.id
  key          = "${local.clean_key_prefix}${each.value}"
  source       = "${var.deploy_source}/${each.value}"
  etag         = filemd5("${var.deploy_source}/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}
