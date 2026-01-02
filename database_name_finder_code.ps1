[Console]::InputEncoding  = [System.Text.Encoding]::GetEncoding(857)
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(857)
chcp 857 | Out-Null

if (-not $env:DBF_UPDATED) {

    $env:DBF_UPDATED = "1"
    $CurrentVersion = "1.0.3"

    $VersionUrl = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/version.txt"
    $ScriptUrl  = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/database_name_finder_code.ps1"

    $ScriptPath = $PSCommandPath
    $TempPath   = "$ScriptPath.new"

    try {
        $LatestVersion = (Invoke-WebRequest $VersionUrl -UseBasicParsing).Content.Trim()
    }
    catch {
        $LatestVersion = $CurrentVersion
    }

    if ($LatestVersion -ne $CurrentVersion) {

        Write-Host ""
        Write-Host "--------------------------------------------" -ForegroundColor Yellow
        Write-Host "Yeni sürüm bulundu! ($LatestVersion)" -ForegroundColor Green
        Write-Host "Mevcut sürüm: $CurrentVersion"
        Write-Host "--------------------------------------------" -ForegroundColor Yellow

        $answer = Read-Host "Güncellemek ister misiniz? (E/H)"

        if ($answer -match "^[eE]$") {

            try {
                Invoke-WebRequest $ScriptUrl -UseBasicParsing -OutFile $TempPath
                Move-Item -Path $TempPath -Destination $ScriptPath -Force

                Write-Host ""
                Write-Host "Güncelleme tamamlandı. Program yeniden başlatılıyor..." -ForegroundColor Green
                Start-Sleep 2

                powershell -ExecutionPolicy Bypass -File $ScriptPath
                exit
            }
            catch {
                Write-Host "Güncelleme başarısız oldu." -ForegroundColor Red
                Start-Sleep 3
            }
        }
        else {
            Write-Host "Güncelleme ertelendi." -ForegroundColor Cyan
            Start-Sleep 2
        }
    }
}

$BasePath =
if ($PSScriptRoot) {
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
    Write-Host "[Bilgi] 'database' klasörü bulunamadı, otomatik oluşturuldu." -ForegroundColor Yellow
}

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(857)
chcp 857 | Out-Null

$Files = @(
    (Join-Path $DatabasePath "textdata_object.txt"),
    (Join-Path $DatabasePath "textdata_equip&skill.txt")
)

foreach ($f in $Files) {
    if (!(Test-Path $f)) {
        Write-Host "Maalesef, dosya bulunamadı: $f" -ForegroundColor Red
        Write-Host "Çıkış yapmak için herhangi bir tuşa basın..."
        exit 1
    }
}

Write-Host "--------------------------------------------------"
Write-Host "Silkroad  database kodlarını almayı kolaylaştırmak için tasarlanmış bir uygulamadır." -ForegroundColor Yellow
Write-Host "created by Echidna." -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Not: Bazı database kodları çıkmayabilir. Eğer çıkmazsa [Database] içindeki textdata_ dosyalarını güncelleyiniz." -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "  Database kodunu istediğiniz"
Write-Host "  Mob - İtem - Pet - Zone - Npc - Skill - Yapı"
$Search = Read-Host "  ismini giriniz. (ör: capricorn gia brain) "

Clear-Host
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Database kodu aranıyor. Lütfen biraz bekle..." -ForegroundColor Blue
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

    $reader = [System.IO.StreamReader]::new($file, [System.Text.Encoding]::GetEncoding(857))

    while (-not $reader.EndOfStream) {

        $line = $reader.ReadLine()
        if (-not $line) { continue }

        $cols = $line -split "`t"
        if ($cols.Count -lt 9) { continue }

        $dbCode = $cols[1]

        for ($i = $cols.Count - 1; $i -ge 0; $i--) {
            if ($cols[$i].Trim() -ne "") {
                $lastText = $cols[$i]
                break
            }
        }

        if (-not $lastText) { continue }

        if ($lastText.ToLower().Contains($searchLower)) {

            $charCount = $lastText.Length
            if ($charCount -gt 40) { continue }

            $wordCount = ($lastText -split ' ').Count
            if ($wordCount -gt 6) { continue }

            if ($lastText -match "[\.\,\%\:]") { continue }

            $entry = "{0,-35} - {1}" -f $dbCode, $lastText

            if     ($dbCode -like "SN_MOB*")        { $MobList       += $entry }
            elseif ($dbCode -like "SN_ITEM*")       { $ItemList      += $entry }
            elseif ($dbCode -like "SN_COS*")        { $CosList       += $entry }
            elseif ($dbCode -like "SN_ZONE*")       { $ZoneList      += $entry }
            elseif ($dbCode -like "SN_NPC*")        { $NpcList       += $entry }
            elseif ($dbCode -like "SN_SKILL*")      { $SkillList     += $entry }
            elseif ($dbCode -like "SN_STRUCTURE*")  { $StructureList += $entry }
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

PrintGroup "Mob İsimleri"        $MobList
PrintGroup "İtem İsimleri"       $ItemList
PrintGroup "Pet / COS İsimleri"  $CosList
PrintGroup "Zone İsimleri"       $ZoneList
PrintGroup "NPC İsimleri"        $NpcList
PrintGroup "Skill İsimleri"      $SkillList
PrintGroup "Yapı İsimleri"       $StructureList

$Total =
    $MobList.Count +
    $ItemList.Count +
    $CosList.Count +
    $ZoneList.Count +
    $NpcList.Count +
    $SkillList.Count +
    $StructureList.Count

if ($Total -eq 0) {
    Write-Host ""
    Write-Host "Database ismi bulunamadı." -ForegroundColor Red
}

$DatabasePath = "database"

$BasePath = $PSScriptRoot
$DatabasePath = Join-Path $BasePath "database"

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Toplam bulunan kayit: $Total"
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host ""
Write-Host "Çıkış yapmak için herhangi bir tuşa basabilirsin..."



