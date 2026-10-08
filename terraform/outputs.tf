output "instance_id" { value = aws_instance.gpu.id }
output "public_ip" { value = aws_eip.llm.public_ip }
output "api_url" { value = "https://${var.domain}" }
output "secrets_arn" { value = aws_secretsmanager_secret.credentials.arn }
output "model" { value = var.model }
