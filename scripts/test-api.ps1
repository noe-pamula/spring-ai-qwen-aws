param([Parameter(Mandatory=$true)][string]$ApiUrl, [Parameter(Mandatory=$true)][string]$ApiKey)
$ErrorActionPreference = 'Stop'
$body = @{model='qwen-training'; messages=@(@{role='user';content='Réponds en une courte phrase : bonjour !'}); max_tokens=100; stream=$false} | ConvertTo-Json -Depth 8
Invoke-RestMethod -Method Post -Uri "$($ApiUrl.TrimEnd('/'))/v1/chat/completions" -Headers @{Authorization="Bearer $ApiKey"} -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 10
