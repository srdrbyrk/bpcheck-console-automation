[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [ValidateRange(1, 2147483647)][int]$DatabaseId,
    [switch]$RunSqlTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'BPCheck-Calistir.ps1'
$testRoot = Join-Path $PSScriptRoot ('Test-Sonuclari\Dogrulama_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Child([string]$Executable, [string]$Arguments, [string]$InputText = '') {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.Arguments = $Arguments
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
        try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($InputText)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(180000)) {
            $process.Kill()
            throw 'Test alt islemi 180 saniyede tamamlanmadi.'
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
    } finally { $process.Dispose() }
}

function Assert-Test([string]$Name, [bool]$Condition) {
    $results.Add([pscustomobject]@{ Test = $Name; Passed = $Condition })
    if (-not $Condition) { throw "TEST FAILED: $Name" }
    Write-Host "PASS: $Name"
}

try {
    if ($RunSqlTest -and -not $PSBoundParameters.ContainsKey('DatabaseId')) {
        throw 'Specify -DatabaseId explicitly for the live SQL test.'
    }
    $parseErrors = $null
    $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$parseErrors)
    Assert-Test 'PowerShell syntax' ($parseErrors.Count -eq 0)
    $prefix = '-NoLogo -NoProfile -File "' + $runner + '" -Language EN -NonInteractive '
    $result = Invoke-Child 'powershell.exe' ($prefix + '-Server ".\SQL2025" -Duration 9')
    Assert-Test 'Duration 9 rejected by parameter validation' ($result.ExitCode -ne 0 -and $result.Output -match 'Duration' -and $result.Output -match '10')
    $result = Invoke-Child 'powershell.exe' ($prefix + '-Server ".\SQL2025" -DatabaseIds "1);SELECT 1--"')
    Assert-Test 'SQL injection scope rejected for correct reason' ($result.ExitCode -ne 0 -and $result.Output -match 'DatabaseIds must')
    $result = Invoke-Child 'powershell.exe' ($prefix + '-Server ".\SQL2025" -DatabaseIds "2147483648"')
    Assert-Test 'Database ID integer overflow rejected' ($result.ExitCode -ne 0 -and $result.Output -match 'int range')
    $result = Invoke-Child 'powershell.exe' ($prefix + '-IndexFragmentation Y -Performance N')
    Assert-Test 'Index checks cannot be silently disabled by conflicting performance option' (
        $result.ExitCode -ne 0 -and $result.Output -match 'IndexFragmentation requires Performance'
    )
    foreach ($language in @('EN', 'TR')) {
        $cancelRoot = Join-Path $testRoot ("Cancel-$language")
        $result = Invoke-Child 'powershell.exe' ('-NoLogo -NoProfile -File "' + $runner + '" -Language ' + $language + ' -OutputDirectory "' + $cancelRoot + '"') ("`r`n" * 10)
        Assert-Test "$language Enter-only uses localhost, lower-load defaults and cancels before SQL" (
            $result.ExitCode -eq 2 -and $result.Output -match 'localhost' -and
            $result.Output -match 'Performance: H' -and $result.Output -match 'Index: H' -and
            $result.Output -match 'TrustServerCertificate: False' -and -not (Test-Path -LiteralPath $cancelRoot)
        )
        $invalid = if ($language -eq 'EN') { 'invalid' } else { 'gecersiz' }
        $result = Invoke-Child 'powershell.exe' ('-NoLogo -NoProfile -File "' + $runner + '" -Language ' + $language) (
            (@('', '', '', $invalid) -join "`r`n") + "`r`n"
        )
        Assert-Test "$language invalid interactive choice fails explicitly" (
            $result.ExitCode -ne 0 -and $result.Output -match 'Y/N'
        )
    }
    $failureRoot = Join-Path $testRoot 'Baglanti-Hatasi'
    $result = Invoke-Child 'powershell.exe' ($prefix + '-Server "tcp:127.0.0.1,1" -TrustServerCertificate -OutputDirectory "' + $failureRoot + '"')
    $failureSummary = Get-ChildItem -LiteralPath $failureRoot -Filter 'Ozet.json' -Recurse | Select-Object -First 1
    $failure = Get-Content -LiteralPath $failureSummary.FullName -Raw | ConvertFrom-Json
    Assert-Test 'Connection failure is nonzero and Failed, not a success fallback' (
        $result.ExitCode -ne 0 -and $failure.Status -eq 'Failed' -and $failure.Error -match 'SqlException' -and $failure.ResultSets -eq 0
    )
    if ($RunSqlTest) {
        foreach ($language in @('EN', 'TR')) {
            $sqlRoot = Join-Path $testRoot "CMD-$language"
            $name = if ($language -eq 'EN') { 'BPCheck-Start.cmd' } else { 'BPCheck-Baslat.cmd' }
            $yes = if ($language -eq 'EN') { 'Y' } else { 'E' }
            $cmd = Join-Path $PSScriptRoot $name
            if (-not (Test-Path -LiteralPath $cmd)) { continue }
            $inputText = @($Server, '', '', '', '', [string]$DatabaseId, $sqlRoot, $yes, $yes, '') -join "`r`n"
            $result = Invoke-Child $env:ComSpec ('/d /c ""' + $cmd + '""') ($inputText + "`r`n")
            $result.Output | Set-Content -LiteralPath (Join-Path $testRoot "CMD-$language.log") -Encoding UTF8
            $reportFile = Get-ChildItem -LiteralPath $sqlRoot -Filter 'Ozet.json' -Recurse | Select-Object -First 1
            $report = Get-Content -LiteralPath $reportFile.FullName -Raw | ConvertFrom-Json
            Assert-Test "$language interactive CMD runs SQL2025 with default options and verified source" (
                $result.ExitCode -eq 0 -and $report.Status -in @('Completed', 'CompletedWithFindings') -and
                $report.ProductVersion -like '17.*' -and $report.ResultSets -gt 1 -and $report.Rows -gt 0 -and -not $report.ProcedureCreated -and
                $report.Performance -eq 'H' -and $report.IndexFragmentation -eq 'H' -and
                $report.DurationSeconds -eq 60 -and $report.Language -eq $language -and $report.ProcedureSourceVerified
            )
            $html = [IO.File]::ReadAllText((Join-Path $reportFile.DirectoryName 'Rapor.html'))
            Assert-Test "$language HTML preserves all result sets, language and closed document" (
                ([regex]::Matches($html, '<table>')).Count -eq $report.ResultSets -and
                $html.Contains('lang="' + $language.ToLowerInvariant() + '"') -and
                $html.TrimEnd().EndsWith('</body></html>')
            )
            Assert-Test "$language expected disabled checks are recorded" ($report.SkippedMessages -gt 0)
        }
    }
} finally {
    ConvertTo-Json -InputObject @($results.ToArray()) -Depth 4 |
        Set-Content -LiteralPath (Join-Path $testRoot 'Testler.json') -Encoding UTF8
    Write-Host "Test ciktilari: $testRoot"
}
