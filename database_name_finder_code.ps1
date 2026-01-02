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
    $CurrentVersion = "1.0.20"

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

        Copy-Item "$ExtractedDatabasePath\*.txt" `
                  -Destination $DatabasePath -Force

        Remove-Item $ZipPath -Force
        Remove-Item (Join-Path $BasePath "DBNameFinder") -Recurse -Force

        Write-Host "[INFO] 'database' klasoru tum .txt dosyalarini geri yuklendi." -ForegroundColor Green
    }
    catch {
        Write-Host "[HATA] 'database' klasoru geri yuklenemedi!" -ForegroundColor Red
    }
}

$Files = Get-ChildItem -Path $DatabasePath -Filter "*.txt" -File | Select-Object -ExpandProperty FullName

Clear-Host
Write-Host "--------------------------------------------------"
Write-Host "Silkroad  database kodlarini almayi kolaylastirmak icin tasarlanmis bir uygulamadir." -ForegroundColor Yellow
Write-Host "Created by Echidna" -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Not: Bazi database kodlari cikmayabilir. Eger cikmazsa [Database] icinde ki textdata_ dosyalarini guncelleyiniz." -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "  Database kodunu istediginiz"
Write-Host "  Mob - Item - Pet - Zone - Npc - Skill - Structure"
$Search = Read-Host "  ismini giriniz. (ornek: capricorn gia brain) "

Clear-Host
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Database kodu araniyor, lutfen biraz bekle..." -ForegroundColor Blue
Write-Host "--------------------------------------------------"

$MobList       = @()
$ItemList      = @()
$CosList       = @()
$ZoneList      = @()
$NpcList       = @()
$SkillList     = @()
$StructureList = @()

$searchLower = $Search.ToLower()

foreach ($file in $Files) {

    $reader = [System.IO.StreamReader]::new(
        $file,
        [System.Text.Encoding]::GetEncoding(857)
    )

    while (-not $reader.EndOfStream) {

        $line = $reader.ReadLine()
        if (-not $line) { continue }

        $cols = $line -split "`t"
        if ($cols.Count -lt 9) { continue }

        $dbCode = $cols[2]

        if ($dbCode -match "(_TT_DESC|_STUDY)$") {
            continue
        }

        $nameText = $null

        if ($cols.Count -gt 13 -and $cols[13].Trim() -ne "") {
            $nameText = $cols[13]
        }
        elseif ($cols.Count -gt 9 -and $cols[9].Trim() -ne "") {
            $nameText = $cols[9]
        }
        else {
            continue
        }

        if ($nameText.ToLower().Contains($searchLower)) {

            if ($nameText.Length -gt 40) { continue }
            if (($nameText -split ' ').Count -gt 6) { continue }
            if ($nameText -match "[\.\,\%\:]") { continue }

            $sourceFile = [System.IO.Path]::GetFileName($file)
            $entry = [PSCustomObject]@{
                Code = $dbCode
                Name = $nameText
                File = $sourceFile
            }

            if     ($dbCode -like "SN_MOB*")       { $MobList       += $entry }
            elseif ($dbCode -like "SN_ITEM*")      { $ItemList      += $entry }
            elseif ($dbCode -like "SN_COS*")       { $CosList       += $entry }
            elseif ($dbCode -like "SN_ZONE*")      { $ZoneList      += $entry }
            elseif ($dbCode -like "SN_NPC*")       { $NpcList       += $entry }
            elseif ($dbCode -like "SN_SKILL*")     { $SkillList     += $entry }
            elseif ($dbCode -like "SN_STRUCTURE*") { $StructureList += $entry }
        }
    }

    $reader.Close()
}

Clear-Host

function PrintGroup($title, $list) {
    if ($list.Count -gt 0) {
        Write-Host ""
        Write-Host "=== $title ===" -ForegroundColor Green
        $i = 1
        foreach ($item in $list) {
        
            Write-Host ("{0,-5} " -f $i) -NoNewline -ForegroundColor DarkGray
            Write-Host ("{0,-35} - {1} " -f $item.Code, $item.Name) -NoNewline -ForegroundColor Cyan
            Write-Host ("[{0}]" -f $item.File) -ForegroundColor Yellow
            
            $i++
        }
    }
}

PrintGroup "Mob Isimleri"        $MobList
PrintGroup "Item Isimleri"       $ItemList
PrintGroup "Pet / COS Isimleri"  $CosList
PrintGroup "Zone Isimleri"       $ZoneList
PrintGroup "NPC Isimleri"        $NpcList
PrintGroup "Skill Isimleri"      $SkillList
PrintGroup "Structure Isimleri"  $StructureList

$Total =
    $MobList.Count +
    $ItemList.Count +
    $CosList.Count +
    $ZoneList.Count +
    $NpcList.Count +
    $SkillList.Count +
    $StructureList.Count

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Toplam bulunan kayit: $Total"
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."




