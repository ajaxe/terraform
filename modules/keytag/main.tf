locals {
  webapp_publish_folder = "${var.webapp_folder}/.publish"
  webapp_zip_name       = "webapp.zip"
  lambda_zip_path       = "${local.webapp_publish_folder}/${local.webapp_zip_name}"
  env_map = {
    dev  = "Development"
    prod = "Production"
  }
  build_runtime = {
    "dotnetcore3.1" = "netcoreapp3.1"
    dotnet6         = "net6.0"
    dotnet8         = "net8.0"
  }
}
data "aws_caller_identity" "current" {}
resource "null_resource" "webapp_build" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = "dotnet publish --output ./.publish --configuration Release --framework ${local.build_runtime[var.runtime]} /p:GenerateRuntimeConfigurationFiles=true --runtime linux-x64 --self-contained false"
    working_dir = var.webapp_folder
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.webapp_publish_folder
  output_path = "${path.module}/files/package.zip"
  depends_on = [
    null_resource.webapp_build
  ]
}

data "aws_iam_policy_document" "lambda_add_on" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParametersByPath"
    ]
    resources = ["*"]
  }
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::keytag-${var.environment}.apogee-dev.com",
      "arn:aws:s3:::keytag-${var.environment}.apogee-dev.com/*"
    ]
  }
}

module "webapp_lambda" {
  source = "../lambda"

  lambda_zip_path        = data.archive_file.lambda_zip
  function_name          = "apg-${var.environment}-${var.app_name}-webapp"
  function_handler       = "Keytag::Keytag.LambdaEntryPoint::FunctionHandlerAsync"
  environment            = var.environment
  app_name               = var.app_name
  deployment_package_key = "${var.app_name}-webapp-${var.environment}/package.zip"
  lambda_add_on_policy   = data.aws_iam_policy_document.lambda_add_on.json
  memory_size            = var.memory_size
  runtime                = var.runtime
  env_variables = {
    ASPNETCORE_ENVIRONMENT = local.env_map[var.environment]
  }

  depends_on = [
    null_resource.webapp_build
  ]
}

module "app_apigateway" {
  source = "../apigateway"

  environment    = var.environment
  rest_api_name  = "KeytagWebapp-${var.environment}"
  root_proxy_uri = module.webapp_lambda.lambda_invoke_arn
  proxy_uri      = module.webapp_lambda.lambda_invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.webapp_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.app_apigateway.api_gateway_execution_arn}/*/*/*"
}