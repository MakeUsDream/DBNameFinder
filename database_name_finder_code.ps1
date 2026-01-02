Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@

$hwnd = [Win32]::GetConsoleWindow()
if ($hwnd -ne [IntPtr]::Zero) {
    [void][Win32]::ShowWindow($hwnd, 3)
}

$RealScriptPath = if ($PSCommandPath) {
    $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
}
else {
    Join-Path (Get-Location) "database_name_finder_code.ps1"
}

try { attrib +h +s "$RealScriptPath" } catch {}

if (-not $env:DBF_UPDATED) {

    $env:DBF_UPDATED = "1"
    $CurrentVersion = "1.0.34"

    $VersionUrl = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/version.txt"
    $ScriptUrl  = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/database_name_finder_code.ps1"

    $ScriptPath = $RealScriptPath
    $TempPath   = "$ScriptPath.new"

    try {
        $LatestVersion = (Invoke-WebRequest -Uri $VersionUrl -UseBasicParsing).Content.Trim()
    }
    catch {
        $LatestVersion = $CurrentVersion
    }

    if ($LatestVersion -ne $CurrentVersion) {

        Write-Host ""
        Write-Host "--------------------------------------------" -ForegroundColor Yellow
        Write-Host "Yeni surum bulundu! ($LatestVersion)" -ForegroundColor Green
        Write-Host "Mevcut surum: $CurrentVersion"
        Write-Host "--------------------------------------------" -ForegroundColor Yellow
        Write-Host ""

        $answer = Read-Host "Guncellemek ister misiniz? (Evet/Hayir)"

        if ($answer -match "^(e|evet)$") {
            try {
                Invoke-WebRequest -Uri $ScriptUrl -OutFile $TempPath -UseBasicParsing
                Move-Item -Path $TempPath -Destination $ScriptPath -Force
                attrib +h +s "$ScriptPath"
                Remove-Item Env:\DBF_UPDATED -ErrorAction SilentlyContinue

                Write-Host ""
                Write-Host "Guncelleme tamamlandi. Program yeniden baslatiliyor..." -ForegroundColor Green
                Write-Host ""

                Start-Sleep 2
                powershell -ExecutionPolicy Bypass -File "$ScriptPath"
                exit
            }
            catch {
                Write-Host "Guncelleme basarisiz oldu." -ForegroundColor Red
                Start-Sleep 3
            }
        }
    }
}

$BasePath = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    Get-Location
}

$DatabasePath = Join-Path $BasePath "database"

if (!(Test-Path $DatabasePath)) {
    New-Item -ItemType Directory -Path $DatabasePath -Force | Out-Null
    Write-Host "[Bilgi] 'database' klasoru bulunamadi, otomatik olarak olusturuldu." -ForegroundColor Yellow
}

$ExistingTxt = Get-ChildItem -Path $DatabasePath -Filter "*.txt" -ErrorAction SilentlyContinue

if ($ExistingTxt.Count -eq 0) {

    Write-Host ""
    Write-Host "[Bilgi] 'database' klasoru bos. .txt dosyalari indiriliyor..." -ForegroundColor Yellow

    $ZipUrl  = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/DBNameFinder.zip"
    $ZipPath = Join-Path $BasePath "DBNameFinder.zip"

    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
        Expand-Archive -Path $ZipPath -DestinationPath $BasePath -Force

        $ExtractedDatabasePath = Join-Path $BasePath "DBNameFinder\database"
        if (!(Test-Path $ExtractedDatabasePath)) {
            throw "Zip icinden 'DBNameFinder\database' cikarilamadi!"
        }

        Copy-Item "$ExtractedDatabasePath\*.txt" -Destination $DatabasePath -Force
        Remove-Item $ZipPath -Force
        Remove-Item (Join-Path $BasePath "DBNameFinder") -Recurse -Force

        Write-Host "[INFO] 'database' klasoru tum .txt dosyalarini geri yuklendi." -ForegroundColor Green
    }
    catch {
        Write-Host "[HATA] 'database' klasoru geri yuklenemedi!" -ForegroundColor Red
    }
}

$Files = Get-ChildItem -Path $DatabasePath -Filter "*.txt" -File |
         Select-Object -ExpandProperty FullName

$DatabaseCodeSet = New-Object System.Collections.Generic.HashSet[string]

Clear-Host

Write-Host "--------------------------------------------------"
Write-Host "Silkroad database kodlarini almayi kolaylastirmak icin tasarlanmis bir uygulamadir." -ForegroundColor Yellow
Write-Host "Created by Echidna" -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""

$Search = Read-Host " Aranacak ismi giriniz "

$searchLower = $Search.ToLower()

function Normalize-Name($text) {
    if (-not $text) { return $null }
    $t = $text.Trim()
    if ($t -match "^\[(.+)\]$") { return $Matches[1] }
    return $t
}

function Is-ValidName($text) {
    if (-not $text) { return $false }
    $t = $text.Trim()
    if ($t.Length -lt 3 -or $t.Length -gt 40) { return $false }
    if ($t -match "^(SN_|ITEM_|SKILL_|NPC_|COS_|ZONE_)") { return $false }
    if ($t -match "^\d+$") { return $false }
    if ($t -match "[\.\,\%\:\=\_\/\\]") { return $false }
    if ($t -notmatch "^[A-Za-z ]+$") { return $false }
    return $true
}

function Get-CodeFromLine($cols) {
    foreach ($c in $cols) {
        if ($c -match "^SN_[A-Z0-9_]+$") {
            return $c
        }
    }
    return $null
}

function Get-NamesFromLine($cols) {

    $names = @()

    foreach ($i in 8..15) {
        if ($cols.Count -gt $i) {
            $n = Normalize-Name $cols[$i]
            if (Is-ValidName $n) {
                $names += $n
            }
        }
    }

    return $names | Select-Object -Unique
}

$ExtraResultList = @()

$ExtraEquipSkillPath = Join-Path $BasePath "textdata_equip&skill"
$ExtraObjectPath     = Join-Path $BasePath "textdata_object"

$ExtraFiles = @()

if (Test-Path $ExtraEquipSkillPath) {
    $ExtraFiles += Get-ChildItem $ExtraEquipSkillPath -Filter "*.txt" -File -ErrorAction SilentlyContinue
}
if (Test-Path $ExtraObjectPath) {
    $ExtraFiles += Get-ChildItem $ExtraObjectPath -Filter "*.txt" -File -ErrorAction SilentlyContinue
}

foreach ($file in $ExtraFiles) {

    $reader = [System.IO.StreamReader]::new(
        $file.FullName,
        [System.Text.Encoding]::GetEncoding(857)
    )

    while (-not $reader.EndOfStream) {

        $line = $reader.ReadLine()
        if (-not $line) { continue }

        $cols = $line -split "`t"
        if ($cols.Count -lt 3) {
            $cols = $line -split "\s{2,}"
        }

        $code = Get-CodeFromLine $cols
        if (-not $code) { continue }

        if ($DatabaseCodeSet.Contains($code)) { continue }

        $names = Get-NamesFromLine $cols
        if ($names.Count -eq 0) { continue }

        foreach ($name in $names) {
            if ($name.ToLower().Contains($searchLower)) {
                $ExtraResultList += [PSCustomObject]@{
                    Code = $code
                    Name = $name
                    File = $file.Name
                }
            }
        }
    }

    $reader.Close()
}

$ExtraResultList = $ExtraResultList | Sort-Object Name -Unique

Clear-Host

Write-Host "=== Extra Textdata (User) ===" -ForegroundColor Green

$i = 1
foreach ($item in $ExtraResultList) {
    Write-Host ("{0,-4} {1,-35} - {2} [{3}]" -f $i, $item.Code, $item.Name, $item.File) -ForegroundColor Cyan
    $i++
}

Write-Host ""
Write-Host "Toplam bulunan kayit: $($ExtraResultList.Count)"
Write-Host ""
Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
