[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [ValidateSet('EN', 'TR')][string]$Language = 'EN',
    [ValidateSet('Windows', 'SQL')][string]$Authentication = 'Windows',
    [string]$Username,
    [ValidateRange(10, 255)][int]$Duration = 60,
    [ValidateSet('E', 'H', 'Y', 'N')][string]$Performance = 'H',
    [ValidateSet('E', 'H', 'Y', 'N')][string]$IndexFragmentation = 'H',
    [ValidateSet('LIMITED', 'SAMPLED', 'DETAILED')][string]$IndexScanMode = 'LIMITED',
    [string]$DatabaseIds,
    [string]$OutputDirectory,
    [ValidateRange(30, 86400)][int]$CommandTimeout = 1800,
    [switch]$TrustServerCertificate,
    [switch]$Install,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageLanguageFile = Join-Path $PSScriptRoot 'Package-Language.txt'
if (-not $PSBoundParameters.ContainsKey('Language') -and (Test-Path -LiteralPath $packageLanguageFile)) {
    $packageLanguage = [IO.File]::ReadAllText($packageLanguageFile).Trim()
    if ($packageLanguage -notin @('EN', 'TR')) { throw 'Invalid Package-Language.txt: expected EN or TR.' }
    $Language = $packageLanguage
}
$sourceCommit = '0b0c137ff2809c086e6a9ae65e9e69ceca13e475'
$sourceHash = '357B11A121B3AE0DAEAB2125CE8AAE8C2F49FEC3561A6A974779C9862C302B72'

$labels = @{
    Authentication = @('Authentication (Windows/SQL)', 'Kimlik dogrulama (Windows/SQL)')
    Duration = @('Sampling interval (10-255 seconds; NOT total runtime)', 'Ornekleme araligi (10-255 saniye; toplam sure DEGIL)')
    Performance = @('Extended performance checks (additional load)', 'Genisletilmis performans kontrolleri (ek yuk)')
    Fragmentation = @('Index fragmentation (additional load)', 'Index fragmentation (ek yuk)')
    ScanMode = @('Index scan mode (LIMITED/SAMPLED/DETAILED)', 'Index tarama modu (LIMITED/SAMPLED/DETAILED)')
    DatabaseIds = @('Database IDs (example 5,7; empty=all eligible databases)', 'Veritabani ID listesi (ornek 5,7; bos=tum uygun veritabanlari)')
    Output = @('Report directory', 'Rapor klasoru')
    Trust = @('Skip certificate validation (trusted TEST environments only)', 'Sertifika dogrulamasini atla (yalnizca guvenilir TEST ortami)')
    InvalidChoice = @('Enter Y/N or E/H.', 'Y/N veya E/H girin.')
    RequiredServer = @('Server cannot be empty.', 'Sunucu bos olamaz.')
    InvalidAuthentication = @('Authentication must be Windows or SQL.', 'Kimlik dogrulama Windows veya SQL olmali.')
    InvalidDuration = @('Duration must be between 10 and 255 seconds.', 'Duration 10-255 saniye arasinda olmali.')
    InvalidScan = @('Invalid index scan mode.', 'Gecersiz index tarama modu.')
    IndexRequiresPerformance = @('IndexFragmentation requires Performance Y/E; the upstream index checks depend on extended performance checks.', 'IndexFragmentation icin Performance E/Y olmali; ozgun index kontrolleri genisletilmis performans kontrollerine baglidir.')
    InvalidIds = @('DatabaseIds must contain comma-separated positive integer IDs only.', 'DatabaseIds yalnizca virgul ile ayrilmis pozitif veritabani ID degerleri icermeli.')
    Overflow = @('Database ID exceeds the int range.', 'Veritabani ID degeri int araligini asiyor.')
    Target = @('Target', 'Hedef')
    Risk = @('Diagnostics add load. OS/disk/SPN checks are disabled. Empty scope covers all eligible databases; this may be expensive.', 'Tanilama yuku olusturur. OS/disk/SPN kontrolleri kapali. Bos kapsam tum uygun veritabanlarini icerir; pahali olabilir.')
    Confirm = @('Connect and run', 'Baglan ve calistir')
    Cancel = @('Cancelled; no SQL connection was opened.', 'Iptal edildi; SQL baglantisi acilmadi.')
    Scope = @('Database scope', 'Veritabani kapsami')
    All = @('ALL eligible databases + instance checks', 'TUM uygun veritabanlari + instance kontrolleri')
    Skipped = @('OS/disk/SPN and buffer-pool descriptor scans disabled. No automatic remediation.', 'OS/disk/SPN ve buffer-pool descriptor taramalari kapali. Otomatik duzeltme yapilmaz.')
    SqlInteractive = @('SQL passwords require interactive mode. Use Windows authentication for scheduling.', 'SQL parolasi icin etkilesimli mod gerekir. Zamanlama icin Windows hesabi kullanin.')
    SqlUser = @('SQL username', 'SQL kullanici adi')
    EmptyUser = @('SQL username cannot be empty.', 'SQL kullanici adi bos olamaz.')
    Password = @('SQL password', 'SQL parolasi')
    Connected = @('Connected', 'Baglandi')
    Install = @('msdb.dbo.usp_bpcheck is missing. Install the Microsoft procedure', 'msdb.dbo.usp_bpcheck yok. Microsoft prosedurunu kur')
    Missing = @('BPCheck is not installed. Use -Install only with installation approval.', 'BPCheck kurulu degil. Onayli ilk kurulum icin -Install kullanin.')
    Download = @('Downloading pinned Microsoft source...', 'Sabit Microsoft kaynagi indiriliyor...')
    Hash = @('Source SHA256 mismatch. Installation/execution stopped.', 'Kaynak SHA256 uyusmuyor. Kurulum/calistirma durduruldu.')
    Installed = @('Microsoft BPCheck procedure created.', 'Microsoft BPCheck proseduru olusturuldu.')
    Existing = @('Existing procedure matches pinned source; left unchanged.', 'Mevcut prosedur sabit kaynakla eslesiyor; degistirilmedi.')
    Mismatch = @('Existing procedure differs from the pinned source. No overwrite or execution performed. Review it manually.', 'Mevcut prosedur sabit kaynaktan farkli. Uzerine yazilmadi ve calistirilmadi. Elle inceleyin.')
    Inaccessible = @('Database ID must exist, be accessible and ONLINE:', 'Veritabani ID mevcut, erisilebilir ve ONLINE olmali:')
    Running = @('Checks running. Reports:', 'Kontroller calisiyor. Raporlar:')
    ResultSet = @('Result set', 'Sonuc kumesi')
    NoResults = @('BPCheck returned no result sets; execution is not successful.', 'BPCheck sonuc kumesi uretmedi; calisma basarili degil.')
    ErrorRows = @('BPCheck returned SQL error rows. Review the partial report.', 'BPCheck SQL hata satirlari dondurdu. Kismi raporu inceleyin.')
    Completed = @('Execution completed. Findings require review; this is NOT a health guarantee.', 'Calistirma tamamlandi. Bulgulari inceleyin; bu bir saglik garantisi DEGILDIR.')
    Error = @('ERROR', 'HATA')
    Status = @('Execution status', 'Calistirma durumu')
    Messages = @('SQL messages', 'SQL mesajlari')
    Reports = @('Report directory', 'Rapor klasoru')
}

function Get-Label([string]$Key) {
    $index = if ($Language -eq 'TR') { 1 } else { 0 }
    return $labels[$Key][$index]
}

function ConvertTo-Choice([string]$Value) {
    switch ($Value.ToUpperInvariant()) {
        { $_ -in @('E', 'Y') } { return 'E' }
        { $_ -in @('H', 'N') } { return 'H' }
        default { throw (Get-Label 'InvalidChoice') }
    }
}

function Read-Choice([string]$Key, [string]$Default = 'H') {
    $displayDefault = $Default
    $options = 'E/H'
    if ($Language -eq 'EN') {
        $options = 'Y/N'
        $displayDefault = if ($Default -eq 'E') { 'Y' } else { 'N' }
    }
    return ConvertTo-Choice (Read-Setting ("{0} ({1})" -f (Get-Label $Key), $options) $displayDefault)
}

function Read-Setting([string]$Label, [string]$Default) {
    $answer = Read-Host "$Label [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim()
}

function ConvertTo-HtmlText($Value) {
    if ($null -eq $Value -or $Value -is [DBNull]) { return '[NULL]' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

$connection = $null
$reader = $null
$html = $null
$text = $null
$messageWriter = $null
$command = $null
$exitCode = 1
$runDirectory = $null
$tableOpen = $false
$password = $null
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$summary = [ordered]@{
    Status = 'Running'
    Stage = 'Input'
    ExitCode = 1
    Language = $Language
    Server = $Server
    ProductVersion = $null
    StartedAt = [DateTimeOffset]::Now.ToString('o')
    FinishedAt = $null
    DurationSeconds = $Duration
    Performance = $Performance
    IndexFragmentation = $IndexFragmentation
    DatabaseIds = $DatabaseIds
    IndexScanMode = $IndexScanMode
    CommandTimeout = $CommandTimeout
    Authentication = $Authentication
    TrustServerCertificate = [bool]$TrustServerCertificate
    ElapsedSeconds = 0
    XpCmdshell = $false
    ResultSets = 0
    Rows = 0
    FindingRows = 0
    MessageWarnings = 0
    SkippedMessages = 0
    SqlErrorRows = 0
    SourceCommit = $sourceCommit
    SourceSHA256 = $sourceHash
    ProcedureCreated = $false
    ProcedureSourceVerified = $false
    Error = $null
}
$messages = [System.Collections.Generic.List[string]]::new()

try {
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $PSScriptRoot 'Raporlar'
    }
    if (-not $NonInteractive) {
        $Server = Read-Setting 'SQL Server / instance' $Server
        $Authentication = Read-Setting (Get-Label 'Authentication') $Authentication
        $Duration = [int](Read-Setting (Get-Label 'Duration') ([string]$Duration))
        $Performance = Read-Choice 'Performance' (ConvertTo-Choice $Performance)
        $IndexFragmentation = Read-Choice 'Fragmentation' (ConvertTo-Choice $IndexFragmentation)
        if ($IndexFragmentation -eq 'E') {
            $IndexScanMode = Read-Setting (Get-Label 'ScanMode') $IndexScanMode
        }
        $DatabaseIds = Read-Setting (Get-Label 'DatabaseIds') $DatabaseIds
        $OutputDirectory = Read-Setting (Get-Label 'Output') $OutputDirectory
        if (-not $TrustServerCertificate) {
            $trustAnswer = Read-Choice 'Trust'
            $TrustServerCertificate = $trustAnswer -eq 'E'
        }
    }

    if ([string]::IsNullOrWhiteSpace($Server)) { throw (Get-Label 'RequiredServer') }
    if ($Authentication -notin @('Windows', 'SQL')) { throw (Get-Label 'InvalidAuthentication') }
    if ($Duration -lt 10 -or $Duration -gt 255) { throw (Get-Label 'InvalidDuration') }
    $Performance = ConvertTo-Choice $Performance
    $IndexFragmentation = ConvertTo-Choice $IndexFragmentation
    if ($IndexFragmentation -eq 'E' -and $Performance -ne 'E') {
        throw (Get-Label 'IndexRequiresPerformance')
    }
    if ($IndexScanMode -notin @('LIMITED', 'SAMPLED', 'DETAILED')) { throw (Get-Label 'InvalidScan') }
    $IndexScanMode = $IndexScanMode.ToUpperInvariant()
    if (-not [string]::IsNullOrWhiteSpace($DatabaseIds)) {
        if ($DatabaseIds.Length -gt 256 -or $DatabaseIds -notmatch '^\s*[1-9][0-9]*(\s*,\s*[1-9][0-9]*)*\s*$') {
            throw (Get-Label 'InvalidIds')
        }
        foreach ($id in ($DatabaseIds -split ',')) {
            $parsed = 0
            if (-not [int]::TryParse($id.Trim(), [ref]$parsed)) { throw (Get-Label 'Overflow') }
        }
        $DatabaseIds = ($DatabaseIds -replace '\s', '')
    }
    $summary.Server = $Server
    $summary.DurationSeconds = $Duration
    $summary.Performance = $Performance
    $summary.IndexFragmentation = $IndexFragmentation
    $summary.DatabaseIds = $DatabaseIds
    $summary.IndexScanMode = $IndexScanMode
    $summary.Authentication = $Authentication
    $summary.TrustServerCertificate = [bool]$TrustServerCertificate

    if (-not $NonInteractive) {
        Write-Host ("`n{0}: {1} | Performance: {2} | Index: {3} | xp_cmdshell: OFF" -f (Get-Label 'Target'), $Server, $Performance, $IndexFragmentation)
        $scope = if ([string]::IsNullOrWhiteSpace($DatabaseIds)) { Get-Label 'All' } else { $DatabaseIds }
        Write-Host ("{0}: {1} | Duration: {2}s | Timeout: {3}s | TrustServerCertificate: {4}" -f (Get-Label 'Scope'), $scope, $Duration, $CommandTimeout, [bool]$TrustServerCertificate)
        Write-Host (Get-Label 'Risk')
        if ((Read-Choice 'Confirm') -ne 'E') {
            throw [System.OperationCanceledException]::new((Get-Label 'Cancel'))
        }
    }

    $summary.Stage = 'ReportSetup'
    $runDirectory = Join-Path ([System.IO.Path]::GetFullPath($OutputDirectory)) (
        'BPCheck_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    )
    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
    $encoding = [System.Text.UTF8Encoding]::new($true)
    $html = [System.IO.StreamWriter]::new((Join-Path $runDirectory 'Rapor.html'), $false, $encoding)
    $text = [System.IO.StreamWriter]::new((Join-Path $runDirectory 'Sonuclar.txt'), $false, $encoding)
    $messageWriter = [System.IO.StreamWriter]::new((Join-Path $runDirectory 'Mesajlar.log'), $false, $encoding)
    $html.WriteLine('<!doctype html><html lang="' + $Language.ToLowerInvariant() + '"><head><meta charset="utf-8"><title>BPCheck</title><style>body{font-family:Segoe UI,sans-serif}table{border-collapse:collapse;font-size:12px}th,td{border:1px solid #ccc;padding:5px;white-space:pre-wrap}th{background:#eee}.finding{background:#fff1cf}</style></head><body>')
    $html.WriteLine('<h1>BPCheck</h1><p>{0}: {1}</p><p>{2}</p>', (Get-Label 'Target'), (ConvertTo-HtmlText $Server), (Get-Label 'Skipped'))

    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source'] = $Server
    $builder['Initial Catalog'] = 'msdb'
    $builder['Application Name'] = 'BPCheck-Console'
    $builder['Connect Timeout'] = 15
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = [bool]$TrustServerCertificate
    $connection = [System.Data.SqlClient.SqlConnection]::new()
    if ($Authentication -eq 'Windows') {
        $builder['Integrated Security'] = $true
    } else {
        if ($NonInteractive) { throw (Get-Label 'SqlInteractive') }
        if ([string]::IsNullOrWhiteSpace($Username)) { $Username = Read-Host (Get-Label 'SqlUser') }
        if ([string]::IsNullOrWhiteSpace($Username)) { throw (Get-Label 'EmptyUser') }
        $password = Read-Host (Get-Label 'Password') -AsSecureString
        $password.MakeReadOnly()
        $connection.Credential = [System.Data.SqlClient.SqlCredential]::new($Username, $password)
    }
    $connection.ConnectionString = $builder.ConnectionString
    $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler]{
        param($sender, $eventArgs)
        foreach ($item in $eventArgs.Errors) {
            $line = '[SQL {0}, severity {1}] {2}' -f $item.Number, $item.Class, $item.Message
            $messages.Add($line)
            $messageWriter.WriteLine($line)
            $messageWriter.Flush()
        }
    }
    $connection.add_InfoMessage($handler)
    $summary.Stage = 'Connection'
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = $CommandTimeout
    $command.CommandText = "SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(32));"
    $summary.ProductVersion = [string]$command.ExecuteScalar()
    Write-Host ("{0}: {1} | SQL {2}" -f (Get-Label 'Connected'), $Server, $summary.ProductVersion)
    $summary.Stage = 'ProcedureCheck'
    $command.CommandText = "SELECT COUNT(*) FROM msdb.sys.procedures WHERE object_id = OBJECT_ID(N'msdb.dbo.usp_bpcheck');"
    $exists = [int]$command.ExecuteScalar() -eq 1
    if (-not $exists) {
        $approved = [bool]$Install
        if (-not $approved -and -not $NonInteractive) {
            $approved = (Read-Choice 'Install') -eq 'E'
        }
        if (-not $approved) { throw (Get-Label 'Missing') }
    }
    $summary.Stage = 'SourceVerification'
    $source = Join-Path $PSScriptRoot 'Check_BP_Servers.sql'
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Host (Get-Label 'Download')
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/microsoft/tigertoolbox/$sourceCommit/BPCheck/Check_BP_Servers.sql" -OutFile $source
    }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $sourceHash) {
        throw (Get-Label 'Hash')
    }
    $sql = [System.IO.File]::ReadAllText($source)
    if (-not $exists) {
        $summary.Stage = 'Installation'
        foreach ($batch in [regex]::Split($sql, '(?im)^\s*GO\s*\r?$')) {
            if (-not [string]::IsNullOrWhiteSpace($batch)) {
                $command.CommandText = $batch
                [void]$command.ExecuteNonQuery()
            }
        }
        $summary.ProcedureCreated = $true
        Write-Host (Get-Label 'Installed')
    }
    $command.CommandText = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'msdb.dbo.usp_bpcheck'));"
    $installedDefinition = [string]$command.ExecuteScalar()
    $expectedDefinition = ([regex]::Split($sql, '(?im)^\s*GO\s*\r?$')[1]).Trim() -replace "`r`n", "`n"
    if (($installedDefinition.Trim() -replace "`r`n", "`n") -cne $expectedDefinition) {
        throw (Get-Label 'Mismatch')
    }
    $summary.ProcedureSourceVerified = $true
    if ($exists) { Write-Host (Get-Label 'Existing') }

    $summary.Stage = 'ScopeValidation'
    if (-not [string]::IsNullOrWhiteSpace($DatabaseIds)) {
        $command.CommandText = 'SELECT database_id FROM sys.databases WHERE state = 0 AND HAS_DBACCESS(name) = 1;'
        $ids = [System.Collections.Generic.List[int]]::new()
        $reader = $command.ExecuteReader()
        while ($reader.Read()) { $ids.Add($reader.GetInt32(0)) }
        $reader.Dispose()
        $reader = $null
        foreach ($id in ($DatabaseIds -split ',')) {
            if ([int]$id -notin $ids) { throw ("{0} {1}" -f (Get-Label 'Inaccessible'), $id) }
        }
    }
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = 'msdb.dbo.usp_bpcheck'
    [void]$command.Parameters.Add('@allow_xpcmdshell', [System.Data.SqlDbType]::Bit)
    $command.Parameters['@allow_xpcmdshell'].Value = $false
    foreach ($pair in @(
        @('@ptochecks', ($Performance -eq 'E')),
        @('@ixfrag', ($IndexFragmentation -eq 'E')),
        @('@diskfrag', $false), @('@bpool_consumer', $false),
        @('@spn_check', $false), @('@gen_scripts', $false), @('@logdetail', $false)
    )) {
        [void]$command.Parameters.Add($pair[0], [System.Data.SqlDbType]::Bit)
        $command.Parameters[$pair[0]].Value = [bool]$pair[1]
    }
    [void]$command.Parameters.Add('@duration', [System.Data.SqlDbType]::TinyInt)
    $command.Parameters['@duration'].Value = $Duration
    [void]$command.Parameters.Add('@ixfragscanmode', [System.Data.SqlDbType]::VarChar, 8)
    $command.Parameters['@ixfragscanmode'].Value = $IndexScanMode
    [void]$command.Parameters.Add('@dbScope', [System.Data.SqlDbType]::VarChar, 256)
    $command.Parameters['@dbScope'].Value = [DBNull]::Value
    if (-not [string]::IsNullOrWhiteSpace($DatabaseIds)) { $command.Parameters['@dbScope'].Value = $DatabaseIds }
    $summary.Stage = 'Checks'
    Write-Host ("{0} {1}" -f (Get-Label 'Running'), $runDirectory)
    $reader = $command.ExecuteReader()
    do {
        if ($reader.FieldCount -gt 0) {
            $summary.ResultSets++
            $html.WriteLine('<h2>{0} {1}</h2><table><thead><tr>', (Get-Label 'ResultSet'), $summary.ResultSets)
            $tableOpen = $true
            $headers = for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $html.WriteLine('<th>{0}</th>', (ConvertTo-HtmlText $reader.GetName($i)))
                $reader.GetName($i)
            }
            $html.WriteLine('</tr></thead><tbody>')
            $text.WriteLine("`r`n=== $(Get-Label 'ResultSet') $($summary.ResultSets) ===")
            $text.WriteLine(($headers -join "`t"))
            while ($reader.Read()) {
                $values = for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    if ($reader.IsDBNull($i)) { '[NULL]' } else { [string]$reader.GetValue($i) }
                }
                $finding = ($values -join ' ') -match '(?i)\b(WARNING|ERROR|FAIL)\b'
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    if ($reader.GetName($i) -eq 'ErrorNumber' -and -not $reader.IsDBNull($i) -and [string]$reader.GetValue($i) -ne '0') {
                        $summary.SqlErrorRows++
                        $finding = $true
                    }
                }
                if ($finding) { $summary.FindingRows++ }
                $class = if ($finding) { ' class="finding"' } else { '' }
                $html.WriteLine("<tr$class>")
                foreach ($value in $values) { $html.WriteLine('<td>{0}</td>', (ConvertTo-HtmlText $value)) }
                $html.WriteLine('</tr>')
                $text.WriteLine((($values | ForEach-Object { $_ -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t' }) -join "`t"))
                $summary.Rows++
            }
            $html.WriteLine('</tbody></table>')
            $tableOpen = $false
            $html.Flush()
            $text.Flush()
        }
    } while ($reader.NextResult())
    $reader.Dispose()
    $reader = $null
    if ($summary.ResultSets -eq 0) { throw (Get-Label 'NoResults') }
    $summary.MessageWarnings = @($messages | Where-Object { $_ -match '(?i)\b(WARNING|ERROR|FAIL)\b' }).Count
    $summary.SkippedMessages = @($messages | Where-Object { $_ -match '(?i)\b(skipped|bypassed)\b' }).Count
    if ($summary.SqlErrorRows -gt 0) { throw (Get-Label 'ErrorRows') }
    $summary.Status = 'CompletedWithFindings'
    if ($summary.FindingRows -eq 0 -and $summary.MessageWarnings -eq 0) { $summary.Status = 'Completed' }
    $exitCode = 0
    $summary.Stage = 'Finished'
    Write-Host (Get-Label 'Completed')
} catch {
    if ($_.Exception -is [System.OperationCanceledException]) {
        $summary.Status = 'Cancelled'
        $exitCode = 2
        Write-Host $_.Exception.Message
    } else {
        $summary.Status = 'Failed'
        $summary.Error = $_.Exception.ToString()
        [Console]::Error.WriteLine("{0}: {1}", (Get-Label 'Error'), $_.Exception.Message)
        if ($null -ne $messageWriter) { $messageWriter.WriteLine($summary.Error) }
    }
} finally {
    $summary.FinishedAt = [DateTimeOffset]::Now.ToString('o')
    $summary.ExitCode = $exitCode
    $summary.ElapsedSeconds = [Math]::Round($clock.Elapsed.TotalSeconds, 2)
    $summary.MessageWarnings = @($messages | Where-Object { $_ -match '(?i)\b(WARNING|ERROR|FAIL)\b' }).Count
    $summary.SkippedMessages = @($messages | Where-Object { $_ -match '(?i)\b(skipped|bypassed)\b' }).Count
    if ($null -ne $reader) { $reader.Dispose() }
    if ($null -ne $command) { $command.Dispose() }
    if ($null -ne $connection) { $connection.Dispose() }
    if ($null -ne $password) { $password.Dispose() }
    if ($null -ne $html) {
        if ($tableOpen) { $html.WriteLine('</tbody></table>') }
        $html.WriteLine('<h2>{0}: {1}</h2>', (Get-Label 'Status'), (ConvertTo-HtmlText $summary.Status))
        $html.WriteLine('<pre>{0}</pre>', (ConvertTo-HtmlText ($summary | ConvertTo-Json -Depth 4)))
        if ($summary.Error) { $html.WriteLine('<pre>{0}</pre>', (ConvertTo-HtmlText $summary.Error)) }
        $html.WriteLine('<h2>{0}</h2><pre>{1}</pre></body></html>', (Get-Label 'Messages'), (ConvertTo-HtmlText ($messages -join "`r`n")))
        $html.Dispose()
    }
    if ($null -ne $text) { $text.Dispose() }
    if ($null -ne $messageWriter) { $messageWriter.Dispose() }
    if ($null -ne $runDirectory) {
        $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runDirectory 'Ozet.json') -Encoding UTF8
        Write-Host ("{0}: {1} | ResultSets: {2} | Rows: {3}" -f (Get-Label 'Status'), $summary.Status, $summary.ResultSets, $summary.Rows)
        Write-Host ("{0}: {1}" -f (Get-Label 'Reports'), $runDirectory)
    }
}
exit $exitCode
