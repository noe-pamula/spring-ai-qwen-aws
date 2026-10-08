$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..\terraform')
try {
  $instance = terraform output -raw instance_id
  $endpoint = terraform output -raw api_url
  Write-Host "Instance : $instance"
  $region = terraform output -json | ConvertFrom-Json
  $regionName = (Get-Content terraform.tfvars -ErrorAction SilentlyContinue | Select-String 'aws_region\s*=\s*"([^\"]+)"' | Select-Object -First 1).Matches.Groups[1].Value
  if (-not $regionName) { $regionName = 'eu-west-3' }
  aws ssm describe-instance-information --region $regionName --filters "Key=InstanceIds,Values=$instance" --query 'InstanceInformationList[*].[InstanceId,PingStatus]' --output table
  try {
    $response = Invoke-RestMethod -Uri "$endpoint/v1/models" -TimeoutSec 12
    Write-Warning 'Réponse sans authentification inattendue : vérifier immédiatement LiteLLM !'
    $response | ConvertTo-Json -Depth 4
  } catch {
    $status = [int]$_.Exception.Response.StatusCode
    if ($status -eq 401 -or $status -eq 403) { Write-Host 'HTTPS joignable ; accès sans clé bien refusé (401/403).' }
    else { Write-Host "API pas encore prête, DNS non propagé ou certificat indisponible : $($_.Exception.Message)" }
  }
  Write-Host 'Pour le diagnostic du bootstrap : sudo tail -100 /var/log/spring-ai-bootstrap.log via SSM.'
} finally { Pop-Location }
