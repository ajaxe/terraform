output "apigateway_base_url" {
  value = aws_api_gateway_deployment.webapp_deploy.invoke_url
}
