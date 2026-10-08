variable "aws_region" {
  type = string
    default = "eu-west-3"
}
variable "instance_type" {
  type = string
    default = "g6.2xlarge"
}
variable "model" {
  type = string
    default = "qwen3:14b"
}
variable "domain" {
  type = string
    description = "FQDN public, ex: llm.example.com"
}
variable "route53_zone_id" {
  type = string
    default = ""
    description = "Optionnel: zone DNS publique Route53. Sinon configurer A record manuellement."
}
variable "subnet_id" {
  type = string
    default = ""
    description = "Optionnel: subnet public existant. Sinon premier subnet VPC default."
}
variable "ami_ssm_parameter" {
  type = string
    default = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-22.04/latest/ami-id"
}
variable "litellm_image" {
  type = string
    default = "ghcr.io/berriai/litellm:main-stable"
    description = "Pour production pinner un tag/version testé"
}
