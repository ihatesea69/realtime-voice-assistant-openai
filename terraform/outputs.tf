# Terraform Outputs

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "coturn_nlb_dns" {
  description = "CoTURN Network Load Balancer DNS"
  value       = aws_lb.coturn.dns_name
}

output "ecr_frontend_url" {
  description = "ECR Frontend Repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_url" {
  description = "ECR Backend Repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Cognito Domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "push_commands" {
  description = "Commands to push Docker images to ECR"
  value       = <<-EOT
# Login to ECR
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.frontend.repository_url}

# Build and push Frontend
docker build -t ${aws_ecr_repository.frontend.repository_url}:latest ./frontend
docker push ${aws_ecr_repository.frontend.repository_url}:latest

# Build and push Backend
docker build -t ${aws_ecr_repository.backend.repository_url}:latest .
docker push ${aws_ecr_repository.backend.repository_url}:latest

# Force ECS to pull new images
aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.frontend.name} --force-new-deployment --region ${var.aws_region}
aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.backend.name} --force-new-deployment --region ${var.aws_region}
EOT
}
