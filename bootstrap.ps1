# AD Cockpit (Windows) — installation en une ligne, sans droits admin, depuis le canal de mises à jour :
#   irm https://raw.githubusercontent.com/Arnaud10H/ad-cockpit-releases/main/bootstrap.ps1 | iex
# Variables facultatives (à définir AVANT) : $env:AD_UPDATE_CHANNEL = 'beta' ; $env:AD_SERVER_URL = 'http://…:8799/' ;
#   $env:AD_UPDATE_TOKEN (canal privé) ; $env:AD_UPDATE_REPO ('owner/repo' GitHub ou URL de base du canal)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repo = if ($env:AD_UPDATE_REPO) { $env:AD_UPDATE_REPO } else { 'Arnaud10H/ad-cockpit-releases' }
$chan = if ($env:AD_UPDATE_CHANNEL) { $env:AD_UPDATE_CHANNEL } else { 'stable' }
$base = if ($repo -like 'http*') { $repo.TrimEnd('/') } else { "https://raw.githubusercontent.com/$repo/main" }
$hdr = @{}
if ($env:AD_UPDATE_TOKEN) { $hdr['Authorization'] = "Bearer $($env:AD_UPDATE_TOKEN)" }
Write-Host "AD Cockpit — installation Windows (canal $chan)" -ForegroundColor Cyan
$m = Invoke-RestMethod -Uri "$base/$chan.json?t=$(Get-Date -UFormat %s)" -Headers $hdr
if (-not $m.windows) { throw "Le canal $chan ne publie pas (encore) de client Windows." }
$w = $m.windows
Write-Host "  version $($w.version) — $($w.url)"
$tmp = Join-Path $env:TEMP ("ad-cockpit-win-" + $w.version)
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'client.zip'
Invoke-WebRequest -Uri $w.url -OutFile $zip -Headers $hdr
if ($w.sha256) {
  $h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($h -ne $w.sha256.ToLowerInvariant()) { throw "Empreinte SHA-256 différente du manifeste — archive refusée." }
  Write-Host "  empreinte SHA-256 vérifiée" -ForegroundColor Green
}
Expand-Archive -Path $zip -DestinationPath $tmp -Force
# serveur du cockpit : AD_SERVER_URL écrase le modèle de config livré (seulement à la première installation)
$cfgModel = Join-Path $tmp 'config.json'
if ($env:AD_SERVER_URL -and (Test-Path $cfgModel) -and -not (Test-Path (Join-Path $env:APPDATA 'ad-cockpit\config.json'))) {
  $j = Get-Content $cfgModel -Raw | ConvertFrom-Json
  $j.serverUrl = $env:AD_SERVER_URL
  if ($env:AD_UPDATE_CHANNEL) { $j | Add-Member -NotePropertyName updateChannel -NotePropertyValue $chan -Force }
  if ($env:AD_UPDATE_TOKEN) { $j | Add-Member -NotePropertyName updateToken -NotePropertyValue $env:AD_UPDATE_TOKEN -Force }
  if ($env:AD_UPDATE_REPO) { $j | Add-Member -NotePropertyName updateRepo -NotePropertyValue $repo -Force }
  $j | ConvertTo-Json -Depth 6 | Set-Content $cfgModel -Encoding UTF8
}
& (Join-Path $tmp 'install.ps1')
Write-Host "Installé. Les mises à jour suivantes passent par le menu de l'icône (zone de notification) ou automatiquement (config.json : autoUpdate = install)." -ForegroundColor Cyan
