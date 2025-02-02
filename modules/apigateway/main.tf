
resource "aws_api_gateway_rest_api" "webapp" {
  name = var.rest_api_name
}

resource "aws_api_gateway_resource" "proxy" {
  count = length(var.proxy_uri) > 0 ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.webapp.id
  parent_id   = aws_api_gateway_rest_api.webapp.root_resource_id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "proxyMethod" {
  count = length(var.proxy_uri) > 0 ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.webapp.id
  resource_id   = aws_api_gateway_resource.proxy[0].id
  http_method   = "ANY"
  authorization = var.authorization
}

resource "aws_api_gateway_integration" "lambdaProxy" {
  count = length(var.proxy_uri) > 0 ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.webapp.id
  resource_id = aws_api_gateway_method.proxyMethod[0].resource_id
  http_method = aws_api_gateway_method.proxyMethod[0].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.proxy_uri
}

resource "aws_api_gateway_method" "rootMethod" {
  rest_api_id   = aws_api_gateway_rest_api.webapp.id
  resource_id   = aws_api_gateway_rest_api.webapp.root_resource_id
  http_method   = "ANY"
  authorization = var.authorization
}

resource "aws_api_gateway_integration" "lambdaRootProxy" {
  rest_api_id = aws_api_gateway_rest_api.webapp.id
  resource_id = aws_api_gateway_method.rootMethod.resource_id
  http_method = aws_api_gateway_method.rootMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.root_proxy_uri
}

resource "aws_api_gateway_stage" "webapp_stage" {
  deployment_id = aws_api_gateway_deployment.webapp_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.webapp.id
  stage_name    = var.environment
}
resource "aws_api_gateway_deployment" "webapp_deploy" {

  triggers = {
    redeployment = sha1(jsonencode(
      coalescelist([
        aws_api_gateway_rest_api.webapp.body,
        aws_api_gateway_integration.lambdaRootProxy.resource_id
        ],
        [aws_api_gateway_integration.lambdaProxy[*].resource_id]
      )
    ))
  }

  lifecycle {
    create_before_destroy = true
  }

  rest_api_id = aws_api_gateway_rest_api.webapp.id
}
