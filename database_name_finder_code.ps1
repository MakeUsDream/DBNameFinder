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
    $CurrentVersion = "1.0.14"

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

                # Update sonrasi tekrar gizle (KESIN)
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

$Files = @(
    (Join-Path $DatabasePath "textdata_object.txt"),
    (Join-Path $DatabasePath "textdata_equip&skill.txt")
)

foreach ($f in $Files) {
    if (!(Test-Path $f)) {
        Write-Host "Maalesef, dosya bulunamadi: $f" -ForegroundColor Red
        Write-Host "Cikmak icin herhangi bir tusa basabilirsin..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

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
        [System.Text.Encoding]::GetEncoding(857) # Silkroad dosyaları
    )

    while (-not $reader.EndOfStream) {

        $line = $reader.ReadLine()
        if (-not $line) { continue }

        $cols = $line -split "`t"
        if ($cols.Count -lt 9) { continue }

        $dbCode = $cols[1]

        if ($dbCode -match "(_TT_DESC|_STUDY)$") {
            continue
        }
        
        $lastText = $null

        for ($i = $cols.Count - 1; $i -ge 0; $i--) {
            if ($cols[$i].Trim() -ne "") {
                $lastText = $cols[$i]
                break
            }
        }

        if (-not $lastText) { continue }

        if ($lastText.ToLower().Contains($searchLower)) {

            if ($lastText.Length -gt 40) { continue }
            if (($lastText -split ' ').Count -gt 6) { continue }
            if ($lastText -match "[\.\,\%\:]") { continue }

            $entry = "{0,-35} - {1}" -f $dbCode, $lastText

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
            Write-Host ("{0,-5} {1}" -f $i, $item) -ForegroundColor Cyan
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
PrintGroup "Structure Isimleri"       $StructureList

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







