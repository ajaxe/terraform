locals {
  exec_output_name      = "route53updater"
  publish_folder        = "${path.cwd}/files"
  exec_output_full_name = "${local.publish_folder}/${local.exec_output_name}"
  lambda_zip_path       = "${local.publish_folder}/${local.exec_output_name}.zip"
}

data "aws_caller_identity" "current" {}

resource "null_resource" "exec_build" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = "go build -o ${local.publish_folder}/${local.exec_output_name} main.go"
    working_dir = var.lambda_folder
    environment = {
      GOOS        = "linux"
      GOARCH      = "amd64"
      CGO_ENABLED = 0
    }
  }
}

resource "null_resource" "zip_windows_package" {
  provisioner "local-exec" {
    command     = "build-lambda-zip.exe -o ${local.exec_output_name}.zip ${local.exec_output_name}"
    working_dir = "${local.publish_folder}/"
  }
  depends_on = [null_resource.exec_build]
}

data "aws_iam_policy_document" "lambda_add_on" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

module "app_lambda" {
  source = "../lambda"

  lambda_zip_path = {
    output_path         = local.lambda_zip_path
    output_sha256       = fileexists(local.lambda_zip_path) ? filesha256(local.lambda_zip_path) : ""
    output_base64sha256 = ""
  }
  function_name          = "${var.app_name}-${var.environment}"
  function_handler       = "route53updater"
  environment            = var.environment
  app_name               = var.app_name
  deployment_package_key = "${var.app_name}-${var.environment}/package.zip"
  lambda_add_on_policy   = data.aws_iam_policy_document.lambda_add_on.json
  memory_size            = var.memory_size
  runtime                = var.runtime
  env_variables = {
    SHARED_KEY     = var.pre_shared_key
    HOSTED_ZONE_ID = var.hosted_zone_id
    AWS_REGION     = var.aws_region
  }

  depends_on = [
    null_resource.zip_windows_package
  ]
}
module "app_apigateway" {
  source = "../apigateway"

  environment    = var.environment
  rest_api_name  = "${var.app_name}-${var.environment}"
  root_proxy_uri = module.app_lambda.lambda_invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.app_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.app_apigateway.api_gateway_execution_arn}/*/*/*"
}
