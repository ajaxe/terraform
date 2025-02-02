output "api_gateway_execution_arn" {
  value = aws_api_gateway_rest_api.webapp.execution_arn
}
output "apigateway_base_url" {
  value = aws_api_gateway_deployment.webapp_deploy.invoke_url
}