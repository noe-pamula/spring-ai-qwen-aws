$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..\terraform')
try {
  Write-Warning 'Cette action détruit EC2, EIP, DNS Route53 (si géré), volume et secret (sans période de récupération).'
  $answer = Read-Host 'Tape DETRUIRE pour confirmer'
  if ($answer -cne 'DETRUIRE') { Write-Host 'Annulé'; exit 0 }
  terraform destroy -auto-approve
  if ($LASTEXITCODE -ne 0) { throw 'La destruction a échoué ; vérifier terraform state et console AWS.' }
} finally { Pop-Location }
