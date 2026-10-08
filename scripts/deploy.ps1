$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location (Join-Path $root 'terraform')
try {
  if (-not (Test-Path 'terraform.tfvars')) { throw 'Copie terraform.tfvars.example en terraform.tfvars et renseigne domain.' }
  terraform init
  if ($LASTEXITCODE -ne 0) { throw 'terraform init a échoué' }
  terraform apply
  if ($LASTEXITCODE -ne 0) { throw 'terraform apply a échoué' }
  Write-Host '\nConfiguration AWS créée. Installation en cours sur EC2 ; lance .\scripts\check.ps1 ensuite.'
  Write-Host 'Si Route53 non utilisé, crée un enregistrement A DNS vers :'
  terraform output -raw public_ip
} finally { Pop-Location }
