[CmdletBinding()]
param(
    [ValidateSet('TR', 'EN')][string[]]$Language = @('TR', 'EN')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$marker = Join-Path $PSScriptRoot 'Package-Language.txt'
if (Test-Path -LiteralPath $marker) {
    $packageLanguage = [IO.File]::ReadAllText($marker).Trim()
    if ($packageLanguage -notin @('TR', 'EN')) { throw 'Invalid package language.' }
    if (-not $PSBoundParameters.ContainsKey('Language')) { $Language = @($packageLanguage) }
    if (@($Language | Where-Object { $_ -ne $packageLanguage }).Count -gt 0) {
        throw 'A single-language package can only rebuild its own language.'
    }
}
$common = @(
    'BPCheck-Calistir.ps1', 'Test-Paket.ps1', 'Build-Release.ps1',
    'LICENSE', 'THIRD-PARTY-NOTICES.txt', 'VALIDATION.md', '.gitignore'
)
$directory = Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$encoding = [Text.UTF8Encoding]::new($false)
foreach ($locale in ($Language | Select-Object -Unique)) {
    $contents = @{}
    foreach ($name in $common) {
        $contents[$name] = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $name))
    }
    $launcher = if ($locale -eq 'TR') { 'BPCheck-Baslat.cmd' } else { 'BPCheck-Start.cmd' }
    $contents[$launcher] = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $launcher))
    $readmeName = if ($locale -eq 'TR' -and -not (Test-Path -LiteralPath $marker)) { 'README.tr.md' } else { 'README.md' }
    $readme = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $readmeName))
    $readme = $readme -replace '(?m)^(?:\[.*\]\(README\.tr\.md\) \| English|[^|\r\n]+ \| \[English\]\(README\.md\))\r?\n', ''
    $contents['README.md'] = $encoding.GetBytes($readme)
    $contents['Package-Language.txt'] = $encoding.GetBytes($locale)
    $quickStart = if ($locale -eq 'TR') {
        "BPCheck - Turkce paket`r`nBPCheck-Baslat.cmd dosyasina cift tiklayin.`r`nUretim riskleri, parametreler ve sonuclar: README.md`r`nVarsayilan hedef localhost. Bos cevaplar ayarlari kabul eder; calistirma ve ilk kurulum acik E/Y onayi ister.`r`n"
    } else {
        "BPCheck - English package`r`nDouble-click BPCheck-Start.cmd.`r`nProduction risks, parameters and results: README.md`r`nDefault target: localhost. Blank answers accept settings; execution and first installation require explicit Y/E approval.`r`n"
    }
    $contents['README.txt'] = $encoding.GetBytes($quickStart)
    $destination = Join-Path $directory "BPCheck-Console-Automation-$locale.zip"
    $stream = [IO.File]::Open($destination, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($name in ($contents.Keys | Sort-Object)) {
                $entry = $archive.CreateEntry($name)
                $output = $entry.Open()
                try { $output.Write($contents[$name], 0, $contents[$name].Length) }
                finally { $output.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
    $archive = [IO.Compression.ZipFile]::OpenRead($destination)
    try {
        if ($archive.Entries.Count -ne $contents.Count) { throw 'Archive entry count mismatch.' }
        foreach ($entry in $archive.Entries) {
            if (-not $contents.ContainsKey($entry.FullName)) { throw 'Unexpected release entry.' }
            $inputStream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try {
                $actual = [BitConverter]::ToString($sha.ComputeHash($inputStream))
                $expected = [BitConverter]::ToString($sha.ComputeHash($contents[$entry.FullName]))
                if ($actual -ne $expected) { throw "Archive hash mismatch: $($entry.FullName)" }
            } finally { $inputStream.Dispose(); $sha.Dispose() }
        }
    } finally { $archive.Dispose() }
    Write-Host "Verified $locale release ($($contents.Count) files): $destination"
}
