$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..\terraform')
try {
  $secret = terraform output -raw secrets_arn
  $region = 'eu-west-3'
  $config = Get-Content terraform.tfvars -ErrorAction SilentlyContinue | Select-String 'aws_region\s*=\s*"([^\"]+)"' | Select-Object -First 1
  if ($config) { $region = $config.Matches.Groups[1].Value }
  $keys = aws secretsmanager get-secret-value --secret-id $secret --region $region --query SecretString --output text
  if ($LASTEXITCODE -ne 0) { throw 'Clés pas encore générées, ou droits AWS insuffisants.' }
  $obj = $keys | ConvertFrom-Json
  Write-Host 'API:' $obj.api_url
  Write-Host 'Modèle:' $obj.model
  foreach ($name in @('stagiaire1','stagiaire2','stagiaire3','formateur')) {
    Write-Host "$($name): $($obj.$name)"
  }
  Write-Warning 'Ne pas distribuer admin_master_key aux stagiaires. Ne pas enregistrer ces clés dans Git.'
} finally { Pop-Location }
