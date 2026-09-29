# Post the 10 wave-2 flyers (graphics\facebook\wave2\1-10) to the Kindred SL Facebook page, one every 30 minutes.
# Run in the VS Code terminal:  powershell -ExecutionPolicy Bypass -File C:\Users\user1\kindred\play\post-wave2.ps1
# Add -Yes to skip the confirmation. Stop any time with Ctrl+C; posts already made stay up.
param([switch]$Yes, [int]$From = 1, [int]$Minutes = 30)
$PageId = '1326254150576514'
$g = "$PSScriptRoot\graphics\facebook\wave2"

$userToken = (Get-Content "$HOME\Desktop\FB_PAGE_TOKEN.txt" -Raw).Trim() -replace '^.*?(EAA\S+).*$', '$1'
try { $pg = Invoke-RestMethod "https://graph.facebook.com/${PageId}?fields=name,access_token" -Headers @{ Authorization = "Bearer $userToken" } -ErrorAction Stop }
catch { Write-Host "Token problem: $($_.ErrorDetails.Message)" -ForegroundColor Red; exit 1 }
$auth = "Authorization: Bearer $($pg.access_token)"
Write-Host "Connected to $($pg.name)." -ForegroundColor Green

if (-not $Yes -and (Read-Host "Post flyers $From-10, one every $Minutes minutes? (y/n)") -ne 'y') { Write-Host 'Cancelled, nothing posted.'; exit }

for ($n = $From; $n -le 10; $n++) {
  $r = curl.exe -s -H $auth -F "source=@$g\$n.png" -F "message=<$g\$n.txt" "https://graph.facebook.com/$PageId/photos" | ConvertFrom-Json
  if ($r.post_id) { Write-Host "$(Get-Date -Format HH:mm:ss)  Posted $n/10 : https://www.facebook.com/$($r.post_id)" -ForegroundColor Green }
  else { Write-Host "Posting $n failed: $($r.error.message)  (rerun with -From $n to continue)" -ForegroundColor Red; exit 1 }
  if ($n -lt 10) { Start-Sleep -Seconds ($Minutes * 60) }
}
Write-Host 'All 10 posted.' -ForegroundColor Green
