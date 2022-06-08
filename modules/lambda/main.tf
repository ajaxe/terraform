# config to copy lambda zip package to S3
data "aws_s3_bucket" "deployment_bucket" {
  bucket = var.deployment_s3_bucket
}
resource "aws_s3_object" "lambda_package" {
  bucket                 = data.aws_s3_bucket.deployment_bucket.id
  key                    = "${var.deployment_key_prefix}/${var.deployment_package_key}"
  source                 = var.lambda_zip_path.output_path
  etag                   = var.lambda_zip_path.output_md5
  server_side_encryption = "AES256"
}

# lambda iam roles
data "aws_iam_policy_document" "lambda_role_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_document.json
}

resource "aws_iam_role_policy_attachment" "execution_policy_attach" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "logging_policy" {
  statement {
    sid    = ""
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = var.function_name
  path        = "/"
  description = "IAM policy for logging from lambda ${var.function_name}"
  policy      = data.aws_iam_policy_document.logging_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "add_on" {
  count       = length(var.lambda_add_on_policy) == 0 ? 0 : 1
  name        = "${var.function_name}-add-on"
  path        = "/"
  description = "IAM policy for accessing related services from lambda ${var.function_name}"
  policy      = var.lambda_add_on_policy
}

resource "aws_iam_role_policy_attachment" "add_on" {
  count      = length(var.lambda_add_on_policy) == 0 ? 0 : 1
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.add_on[count.index].arn

  depends_on = [
    aws_iam_policy.add_on
  ]
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda.arn
  publish          = true
  handler          = var.function_handler
  memory_size      = var.memory_size
  timeout          = var.lambda_timeout
  runtime          = var.runtime
  s3_bucket        = data.aws_s3_bucket.deployment_bucket.id
  s3_key           = aws_s3_object.lambda_package.id
  source_code_hash = var.lambda_zip_path.output_base64sha256

  dynamic "environment" {
    for_each = length(var.env_variables) == 0 ? [] : [1]
    content {
      variables = var.env_variables
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution_policy_attach,
    aws_iam_role.lambda,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}
