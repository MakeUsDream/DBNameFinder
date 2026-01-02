if (-not $env:DBF_UPDATED) {

    $env:DBF_UPDATED = "1"
    $CurrentVersion = "1.0.5"

    $VersionUrl = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/version.txt"
    $ScriptUrl  = "https://raw.githubusercontent.com/MakeUsDream/DBNameFinder/main/database_name_finder_code.ps1"

    $ScriptPath = $PSCommandPath
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
        Write-Host "Yeni sürüm bulundu! ($LatestVersion)" -ForegroundColor Green
        Write-Host "Mevcut sürüm: $CurrentVersion"
        Write-Host "--------------------------------------------" -ForegroundColor Yellow

        $answer = Read-Host "Güncellemek ister misiniz? (Evet/Hayır)"

        if ($answer -match "^(e|evet)$") {

            try {
                Invoke-WebRequest -Uri $ScriptUrl -OutFile $TempPath -UseBasicParsing
                Move-Item -Path $TempPath -Destination $ScriptPath -Force

                Remove-Item Env:\DBF_UPDATED -ErrorAction SilentlyContinue

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
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

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
    Write-Host "[Bilgi] 'database' klasörü bulunamadı, otomatik oluşturuldu." -ForegroundColor Yellow
}

$Files = @(
    (Join-Path $DatabasePath "textdata_object.txt"),
    (Join-Path $DatabasePath "textdata_equip&skill.txt")
)

foreach ($f in $Files) {
    if (!(Test-Path $f)) {
        Write-Host "Maalesef, dosya bulunamadı: $f" -ForegroundColor Red
        Write-Host "Çıkış yapmak için herhangi bir tuşa basın..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

Clear-Host
Write-Host "--------------------------------------------------"
Write-Host "Silkroad database kodlarını almayı kolaylaştırmak" -ForegroundColor Yellow
Write-Host "için tasarlanmış bir uygulamadır." -ForegroundColor Yellow
Write-Host "Created by Echidna" -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "Not: Bazı database kodları çıkmayabilir." -ForegroundColor Yellow
Write-Host "Gerekirse textdata_ dosyalarını güncelleyin." -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "Mob - İtem - Pet - Zone - NPC - Skill - Yapı"
$Search = Read-Host "Aramak istediğiniz ismi giriniz"

Clear-Host
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Database kodu aranıyor, lütfen bekleyin..." -ForegroundColor Blue
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

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Toplam bulunan kayıt: $Total"
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "Çıkmak için herhangi bir tuşa basabilirsiniz..."
