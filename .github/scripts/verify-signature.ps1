Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$filesFolder = $env:FILES_FOLDER
$filesFilter = $env:FILES_FILTER

if ([string]::IsNullOrWhiteSpace($filesFolder)) {
  throw "Missing required environment variable: FILES_FOLDER"
}
if ([string]::IsNullOrWhiteSpace($filesFilter)) {
  throw "Missing required environment variable: FILES_FILTER"
}

$filesFolder = $filesFolder.Trim()
$filters = $filesFilter.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if (-not (Test-Path -LiteralPath $filesFolder)) {
  throw "Files folder does not exist: $filesFolder"
}

$failed = $false
$totalFiles = 0

foreach ($filter in $filters) {
  $files = Get-ChildItem -Path $filesFolder -Filter $filter -File -ErrorAction Stop
  foreach ($file in $files) {
    $totalFiles++
    if ($file.Extension -eq ".nupkg") {
      Write-Host "Verifying NuGet signature on $($file.FullName)"
      dotnet nuget verify $file.FullName
      if ($LASTEXITCODE -ne 0) {
        Write-Error "NuGet signature verification failed on $($file.Name)"
        $failed = $true
      }
      continue
    }

    $sig = Get-AuthenticodeSignature -FilePath $file.FullName
    if ($sig.Status -ne "Valid") {
      Write-Error "Invalid or missing signature on $($file.Name): $($sig.Status)"
      $failed = $true
    } else {
      Write-Host "Valid signature on $($file.Name): $($sig.SignerCertificate.Subject)"
    }
  }
}

if ($totalFiles -eq 0) {
  throw "No files matched FILES_FILTER in folder: $filesFolder"
}
if ($failed) {
  throw "Signature verification failed for one or more files."
}

Write-Host "All matched files passed signature verification."
