Write-Host "### GUNCEL SURUM AKTIF ###" -ForegroundColor Green

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
    Write-Host "[Bilgi] 'database' klasörü bulunamadý, otomatik oluþturuldu." -ForegroundColor Yellow
}

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(857)
chcp 857 | Out-Null

$Files = @(
    (Join-Path $DatabasePath "textdata_object.txt"),
    (Join-Path $DatabasePath "textdata_equip&skill.txt")
)

foreach ($f in $Files) {
    if (!(Test-Path $f)) {
        Write-Host "Maalesef, dosya bulunamadý: $f" -ForegroundColor Red
        Write-Host "Çýkýþ yapmak için herhangi bir tuþa basýn..."
        exit 1
    }
}

Write-Host "--------------------------------------------------"
Write-Host "Silkroad  database kodlarýný almayý kolaylaþtýrmak için tasarlanmýþ bir uygulamadýr." -ForegroundColor Yellow
Write-Host "created by Echidna." -ForegroundColor Yellow
Write-Host "Discord: @makeusdream" -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Not: Bazý database kodlarý çýkmayabilir. Eðer çýkmazsa [Database] içindeki textdata_ dosyalarýný güncelleyiniz." -ForegroundColor Yellow
Write-Host "--------------------------------------------------"
Write-Host ""
Write-Host "  Database kodunu istediðiniz"
Write-Host "  Mob - Ýtem - Pet - Zone - Npc - Skill - Yapý"
$Search = Read-Host "  ismini giriniz. (ör: capricorn gia brain) "

Clear-Host
Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "Database kodu aranýyor. Lütfen biraz bekle..." -ForegroundColor Blue
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

PrintGroup "Mob Ýsimleri"        $MobList
PrintGroup "Ýtem Ýsimleri"       $ItemList
PrintGroup "Pet / COS Ýsimleri"  $CosList
PrintGroup "Zone Ýsimleri"       $ZoneList
PrintGroup "NPC Ýsimleri"        $NpcList
PrintGroup "Skill Ýsimleri"      $SkillList
PrintGroup "Yapý Ýsimleri"       $StructureList

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
    Write-Host "Database ismi bulunamadý." -ForegroundColor Red
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
Write-Host "Çýkýþ yapmak için herhangi bir tuþa basabilirsin..."

