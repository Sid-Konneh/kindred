# Post wave-2 flyer $From now and schedule the rest on Facebook, one every $Hours hours, as MAIN FEED posts
# on the Kindred SL page (photo attached to the post, not uploaded into the photo album).
# Facebook publishes the scheduled ones itself, so this PC can be off. See them in Meta Business Suite → Planner.
# Run:  powershell -ExecutionPolicy Bypass -File C:\Users\user1\kindred\play\schedule-wave2.ps1 [-From 4] [-Hours 24] [-Yes]
param([int]$From = 4, [int]$To = 10, [int]$Hours = 24, [switch]$Yes)
$PageId = '1326254150576514'
$g = "$PSScriptRoot\graphics\facebook\wave2"
$api = 'https://graph.facebook.com/v21.0'

$userToken = (Get-Content "$HOME\Desktop\FB_PAGE_TOKEN.txt" -Raw).Trim() -replace '^.*?(EAA\S+).*$', '$1'
try { $pg = Invoke-RestMethod "$api/${PageId}?fields=name,access_token" -Headers @{ Authorization = "Bearer $userToken" } -ErrorAction Stop }
catch { Write-Host "Token problem: $($_.ErrorDetails.Message)" -ForegroundColor Red; exit 1 }
$pageToken = $pg.access_token
$auth = "Authorization: Bearer $pageToken"
Write-Host "Connected to $($pg.name)." -ForegroundColor Green

$start = [DateTimeOffset]::UtcNow
Write-Host "Post $From now, then $($From + 1)-$To every $Hours hours (last one $($start.AddHours(($To - $From) * $Hours).ToLocalTime().ToString('ddd d MMM HH:mm')))."
if (-not $Yes -and (Read-Host 'Go ahead? (y/n)') -ne 'y') { Write-Host 'Cancelled, nothing posted.'; exit }

# UTF-8 form body, so emoji in captions survive Windows PowerShell 5.1
function Post-Form($url, $fields) {
  $body = ($fields.GetEnumerator() | ForEach-Object { [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString([string]$_.Value) }) -join '&'
  Invoke-RestMethod $url -Method Post -Headers @{ Authorization = "Bearer $pageToken" } -ContentType 'application/x-www-form-urlencoded; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
}

for ($n = $From; $n -le $To; $n++) {
  $now = $n -eq $From
  $when = $start.AddHours(($n - $From) * $Hours)
  # 1. upload the flyer without publishing it (so it doesn't appear as its own photo post)
  $photoArgs = @('-s', '-H', $auth, '-F', "source=@$g\$n.png", '-F', 'published=false')
  if (-not $now) { $photoArgs += @('-F', 'temporary=true') }
  $photo = curl.exe @photoArgs "$api/$PageId/photos" | ConvertFrom-Json
  if (-not $photo.id) { Write-Host "Uploading flyer $n failed: $($photo.error.message)  (rerun with -From $n)" -ForegroundColor Red; exit 1 }
  # 2. the main feed post, with the flyer attached
  $fields = [ordered]@{ message = (Get-Content "$g\$n.txt" -Raw -Encoding UTF8).Trim(); 'attached_media[0]' = "{`"media_fbid`":`"$($photo.id)`"}" }
  if (-not $now) { $fields.published = 'false'; $fields.scheduled_publish_time = $when.ToUnixTimeSeconds() }
  try { $post = Post-Form "$api/$PageId/feed" $fields }
  catch { Write-Host "Post $n failed: $($_.ErrorDetails.Message)  (rerun with -From $n)" -ForegroundColor Red; exit 1 }
  if ($now) { Write-Host "Posted $n now: https://www.facebook.com/$($post.id)" -ForegroundColor Green }
  else { Write-Host "Scheduled $n for $($when.ToLocalTime().ToString('ddd d MMM HH:mm'))  ($($post.id))" -ForegroundColor Green }
}
Write-Host 'Done.' -ForegroundColor Green
