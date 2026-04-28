param(
    [string]$GamePath,
    [switch]$NoForceEnglishSlot,
    [switch]$RestoreEnglish
)

$ErrorActionPreference = "Stop"

function Read-U16BE([byte[]]$Bytes, [int]$Index) {
    return ([int]$Bytes[$Index] -shl 8) -bor [int]$Bytes[$Index + 1]
}

function Read-U32BE([byte[]]$Bytes, [int]$Index) {
    return (([int]$Bytes[$Index] -shl 24) -bor
        ([int]$Bytes[$Index + 1] -shl 16) -bor
        ([int]$Bytes[$Index + 2] -shl 8) -bor
        [int]$Bytes[$Index + 3])
}

function Write-U16BE([System.IO.Stream]$Stream, [int]$Value) {
    $Stream.WriteByte(($Value -shr 8) -band 255)
    $Stream.WriteByte($Value -band 255)
}

function Write-U32BE([System.IO.Stream]$Stream, [int]$Value) {
    $Stream.WriteByte(($Value -shr 24) -band 255)
    $Stream.WriteByte(($Value -shr 16) -band 255)
    $Stream.WriteByte(($Value -shr 8) -band 255)
    $Stream.WriteByte($Value -band 255)
}

function Read-Utf([byte[]]$Bytes, [ref]$Index) {
    $Length = Read-U16BE $Bytes $Index.Value
    $Index.Value += 2
    $Text = [System.Text.Encoding]::UTF8.GetString($Bytes, $Index.Value, $Length)
    $Index.Value += $Length
    return $Text
}

function Write-Utf([System.IO.Stream]$Stream, [string]$Text) {
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    if ($Bytes.Length -gt 65535) {
        throw "Слишком длинная строка для формата UTF: $($Bytes.Length) байт"
    }

    Write-U16BE $Stream $Bytes.Length
    $Stream.Write($Bytes, 0, $Bytes.Length)
}

function Load-XmlStringMap([string[]]$Paths) {
    $Map = @{}
    $Regex = [regex]'(?s)<data\s+name="([^"]+)"[^>]*>\s*<value>(.*?)</value>\s*</data>'

    foreach ($Path in $Paths) {
        if (-not (Test-Path -LiteralPath $Path)) {
            continue
        }

        $Text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        foreach ($Match in $Regex.Matches($Text)) {
            $Name = $Match.Groups[1].Value
            $Value = $Match.Groups[2].Value

            if ($Value -match '(?s)^<!\[CDATA\[(.*)\]\]>$') {
                $Value = $Matches[1]
            }

            $Map[$Name] = [System.Net.WebUtility]::HtmlDecode($Value)
        }
    }

    return $Map
}

function Read-StaticLanguageValues([byte[]]$Data) {
    $Index = 0
    $Version = Read-U32BE $Data $Index
    $Index += 4

    $IsStatic = $false
    if ($Version -gt 0) {
        $IsStatic = ($Data[$Index] -ne 0)
        $Index += 1
    }

    $LanguageId = Read-Utf $Data ([ref]$Index)
    $Total = Read-U32BE $Data $Index
    $Index += 4

    if (-not $IsStatic) {
        throw "Сегмент языка '$LanguageId' не является статическим."
    }

    $Values = New-Object System.Collections.Generic.List[string]
    for ($I = 0; $I -lt $Total; $I++) {
        $Values.Add((Read-Utf $Data ([ref]$Index)))
    }

    return ,$Values
}

function Build-StaticLanguage([string]$LanguageId, [string[]]$Values) {
    $Stream = New-Object System.IO.MemoryStream

    Write-U32BE $Stream 1
    $Stream.WriteByte(1)
    Write-Utf $Stream $LanguageId
    Write-U32BE $Stream $Values.Count

    foreach ($Value in $Values) {
        Write-Utf $Stream $Value
    }

    return $Stream.ToArray()
}

function Download-SourceFiles([string]$TempDir) {
    $Base = "https://raw.githubusercontent.com/MCLCE/MinecraftConsoles/main/"
    $Files = @(
        "Minecraft.Client/Windows64Media/strings.h",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/AdditionalStrings.xml",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/EULA.xml",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/PS4Strings.xml",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/stringsGeneric.xml",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/stringsLeaderboards.xml",
        "Minecraft.Client/OrbisMedia/loc/ru-RU/stringsPlatformSpecific.xml",
        "Minecraft.Client/DurangoMedia/loc/ru-RU/stringsGeneric.xml",
        "Minecraft.Client/DurangoMedia/loc/ru-RU/stringsPlatformSpecific.xml",
        "Minecraft.Client/DurangoMedia/loc/ru-RU/4J_stringsGeneric.xml",
        "Minecraft.Client/DurangoMedia/loc/ru-RU/4J_stringsPlatformSpecific.xml"
    )

    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $Downloaded = @{}

    foreach ($File in $Files) {
        $OutFile = Join-Path $TempDir ($File -replace "[\\/]", "__")
        Invoke-WebRequest -Uri ($Base + $File) -OutFile $OutFile -Headers @{ "User-Agent" = "minecraft-legacy-rus-installer" }
        $Downloaded[$File] = $OutFile
    }

    return $Downloaded
}

function Get-ManualOverrides {
    $Overrides = @{
        IDS_WINDOWS_EXIT = "Выйти из Minecraft"
        IDS_LANGUAGE_SELECTOR = "Языки"
        IDS_LANG_SYSTEM = "Язык системы"
        IDS_LANG_ENGLISH = "Английский"
        IDS_LANG_GERMAN = "Немецкий"
        IDS_LANG_SPANISH = "Испанский"
        IDS_LANG_SPANISH_SPAIN = "Испанский (Испания)"
        IDS_LANG_SPANISH_LATIN_AMERICA = "Испанский (Латинская Америка)"
        IDS_LANG_FRENCH = "Французский"
        IDS_LANG_ITALIAN = "Итальянский"
        IDS_LANG_PORTUGUESE = "Португальский"
        IDS_LANG_PORTUGUESE_PORTUGAL = "Португальский (Португалия)"
        IDS_LANG_PORTUGUESE_BRAZIL = "Португальский (Бразилия)"
        IDS_LANG_JAPANESE = "Японский"
        IDS_LANG_KOREAN = "Корейский"
        IDS_LANG_CHINESE_TRADITIONAL = "Китайский (традиционный)"
        IDS_LANG_CHINESE_SIMPLIFIED = "Китайский (упрощённый)"
        IDS_LANG_DANISH = "Датский"
        IDS_LANG_FINISH = "Финский"
        IDS_LANG_DUTCH = "Нидерландский"
        IDS_LANG_POLISH = "Польский"
        IDS_LANG_RUSSIAN = "Русский"
        IDS_LANG_SWEDISH = "Шведский"
        IDS_LANG_NORWEGIAN = "Норвежский"
        IDS_LANG_GREEK = "Греческий"
        IDS_LANG_TURKISH = "Турецкий"
        IDS_INCREASE_WORLD_SIZE = "Увеличить размер мира"
        IDS_INCREASE_WORLD_SIZE_OVERWRITE_EDGES = "Перезаписать края"
        IDS_GAMEOPTION_INCREASE_WORLD_SIZE = "Увеличить размер мира"
        IDS_GAMEOPTION_INCREASE_WORLD_SIZE_OVERWRITE_EDGES = "Перезаписать края"
        IDS_TILE_COMMAND_BLOCK = "Командный блок"
        IDS_TILE_BEACON = "Маяк"
        IDS_TILE_CHEST_TRAP = "Сундук-ловушка"
        IDS_TILE_WEIGHTED_PLATE_LIGHT = "Весовая нажимная пластина (лёгкая)"
        IDS_TILE_WEIGHTED_PLATE_HEAVY = "Весовая нажимная пластина (тяжёлая)"
        IDS_TILE_COMPARATOR = "Редстоуновый компаратор"
        IDS_TILE_DAYLIGHT_DETECTOR = "Датчик дневного света"
        IDS_TILE_REDSTONE_BLOCK = "Блок редстоуна"
        IDS_TILE_HOPPER = "Воронка"
        IDS_TILE_ACTIVATOR_RAIL = "Активирующие рельсы"
        IDS_TILE_DROPPER = "Выбрасыватель"
        IDS_TILE_HAY = "Блок сена"
        IDS_TILE_HARDENED_CLAY = "Обожжённая глина"
        IDS_TILE_COAL = "Блок угля"
        IDS_NETHER_STAR = "Звезда Нижнего мира"
        IDS_FIREWORKS = "Фейерверк"
        IDS_FIREWORKS_CHARGE = "Звёздочка фейерверка"
        IDS_ITEM_COMPARATOR = "Редстоуновый компаратор"
        IDS_ITEM_MINECART_TNT = "Вагонетка с ТНТ"
        IDS_ITEM_MINECART_HOPPER = "Вагонетка с воронкой"
        IDS_ITEM_IRON_HORSE_ARMOR = "Железная конская броня"
        IDS_ITEM_GOLD_HORSE_ARMOR = "Золотая конская броня"
        IDS_ITEM_DIAMOND_HORSE_ARMOR = "Алмазная конская броня"
        IDS_ITEM_LEAD = "Поводок"
        IDS_ITEM_NAME_TAG = "Бирка"
        IDS_BAT = "Летучая мышь"
        IDS_WITCH = "Ведьма"
        IDS_HORSE = "Лошадь"
        IDS_DONKEY = "Осёл"
        IDS_MULE = "Мул"
        IDS_ZOMBIE_HORSE = "Лошадь-зомби"
        IDS_SKELETON_HORSE = "Лошадь-скелет"
        IDS_WITHER = "Иссушитель"
        IDS_MOB_GRIEFING = "Разрушения мобами"
        IDS_KEEP_INVENTORY = "Сохранять инвентарь"
        IDS_MOB_SPAWNING = "Появление мобов"
        IDS_MOB_LOOT = "Добыча с мобов"
        IDS_TILE_DROPS = "Выпадение блоков"
        IDS_NATURAL_REGEN = "Естественная регенерация"
        IDS_DAYLIGHT_CYCLE = "Цикл дня и ночи"
        IDS_RICHPRESENCE_IDLE = "Бездействует"
        IDS_RICHPRESENCE_MENUS = "В меню"
        IDS_RICHPRESENCESTATE_BOATING = "В лодке"
        IDS_RICHPRESENCESTATE_FISHING = "Рыбачит"
        IDS_RICHPRESENCESTATE_CRAFTING = "Создаёт предметы"
        IDS_RICHPRESENCESTATE_NETHER = "В Нижнем мире"
        IDS_RICHPRESENCESTATE_ENCHANTING = "Зачаровывает"
        IDS_RICHPRESENCESTATE_BREWING = "Варит зелье"
    }

    $Colors = @{
        BLACK = @("Чёрная", "Чёрное", "Чёрный")
        RED = @("Красная", "Красное", "Красный")
        GREEN = @("Зелёная", "Зелёное", "Зелёный")
        BROWN = @("Коричневая", "Коричневое", "Коричневый")
        BLUE = @("Синяя", "Синее", "Синий")
        PURPLE = @("Фиолетовая", "Фиолетовое", "Фиолетовый")
        CYAN = @("Бирюзовая", "Бирюзовое", "Бирюзовый")
        SILVER = @("Светло-серая", "Светло-серое", "Светло-серый")
        GRAY = @("Серая", "Серое", "Серый")
        PINK = @("Розовая", "Розовое", "Розовый")
        LIME = @("Лаймовая", "Лаймовое", "Лаймовый")
        YELLOW = @("Жёлтая", "Жёлтое", "Жёлтый")
        LIGHT_BLUE = @("Голубая", "Голубое", "Голубой")
        MAGENTA = @("Пурпурная", "Пурпурное", "Пурпурный")
        ORANGE = @("Оранжевая", "Оранжевое", "Оранжевый")
        WHITE = @("Белая", "Белое", "Белый")
    }

    foreach ($Color in $Colors.Keys) {
        $Overrides["IDS_TILE_STAINED_CLAY_$Color"] = "$($Colors[$Color][0]) окрашенная глина"
        $Overrides["IDS_TILE_STAINED_GLASS_$Color"] = "$($Colors[$Color][1]) окрашенное стекло"
        $Overrides["IDS_TILE_STAINED_GLASS_PANE_$Color"] = "$($Colors[$Color][0]) окрашенная стеклянная панель"
        $Overrides["IDS_FIREWORKS_CHARGE_$Color"] = $Colors[$Color][2]
    }

    return $Overrides
}

function Test-GamePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $ArchivePath = Join-Path $Path "Common\Media\MediaWindows64.arc"
    return Test-Path -LiteralPath $ArchivePath
}

function Resolve-GamePath([string]$RequestedPath) {
    if (Test-GamePath $RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        throw "Не найден файл: $(Join-Path $RequestedPath 'Common\Media\MediaWindows64.arc')"
    }

    $ScriptDirectory = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($ScriptDirectory)) {
        $ScriptDirectory = Split-Path -Parent $MyInvocation.ScriptName
    }
    $PackageRoot = Split-Path -Parent $ScriptDirectory
    $PackageParent = Split-Path -Parent $PackageRoot

    $Candidates = New-Object System.Collections.Generic.List[string]
    foreach ($Candidate in @(
        $PackageRoot,
        (Join-Path $PackageRoot "LCEWindows64"),
        $PackageParent,
        (Join-Path $PackageParent "LCEWindows64"),
        (Join-Path $PackageParent ".minecraft legacy\LCEWindows64"),
        (Get-Location).Path
    )) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate) -and -not $Candidates.Contains($Candidate)) {
            $Candidates.Add($Candidate)
        }
    }

    $Found = @($Candidates | Where-Object { Test-GamePath $_ })
    if ($Found.Count -eq 1) {
        Write-Host "Папка игры найдена автоматически: $($Found[0])"
        return (Resolve-Path -LiteralPath $Found[0]).Path
    }

    if ($Found.Count -gt 1) {
        Write-Host "Найдено несколько вариантов папки игры:"
        for ($I = 0; $I -lt $Found.Count; $I++) {
            Write-Host "$($I + 1). $($Found[$I])"
        }

        $Choice = Read-Host "Введите номер нужного варианта или полный путь к LCEWindows64"
        if ($Choice -match '^\d+$') {
            $Index = [int]$Choice - 1
            if ($Index -ge 0 -and $Index -lt $Found.Count) {
                return (Resolve-Path -LiteralPath $Found[$Index]).Path
            }
        }

        if (Test-GamePath $Choice) {
            return (Resolve-Path -LiteralPath $Choice).Path
        }
    }

    $DriveCandidates = New-Object System.Collections.Generic.List[string]
    foreach ($Drive in Get-PSDrive -PSProvider FileSystem) {
        if (-not [string]::IsNullOrWhiteSpace($Drive.Root)) {
            $Candidate = Join-Path $Drive.Root ".minecraft legacy\LCEWindows64"
            if (-not $DriveCandidates.Contains($Candidate)) {
                $DriveCandidates.Add($Candidate)
            }
        }
    }

    $DriveFound = @($DriveCandidates | Where-Object { Test-GamePath $_ })
    if ($DriveFound.Count -eq 1) {
        Write-Host "Папка игры найдена автоматически: $($DriveFound[0])"
        return (Resolve-Path -LiteralPath $DriveFound[0]).Path
    }

    if ($DriveFound.Count -gt 1) {
        Write-Host "Найдено несколько вариантов папки игры:"
        for ($I = 0; $I -lt $DriveFound.Count; $I++) {
            Write-Host "$($I + 1). $($DriveFound[$I])"
        }

        $Choice = Read-Host "Введите номер нужного варианта или полный путь к LCEWindows64"
        if ($Choice -match '^\d+$') {
            $Index = [int]$Choice - 1
            if ($Index -ge 0 -and $Index -lt $DriveFound.Count) {
                return (Resolve-Path -LiteralPath $DriveFound[$Index]).Path
            }
        }

        if (Test-GamePath $Choice) {
            return (Resolve-Path -LiteralPath $Choice).Path
        }
    }

    Write-Host "Не удалось автоматически найти папку игры."
    Write-Host "Нужна папка LCEWindows64, внутри которой есть Common\Media\MediaWindows64.arc."
    $ManualPath = Read-Host "Введите полный путь к LCEWindows64"

    if (Test-GamePath $ManualPath) {
        return (Resolve-Path -LiteralPath $ManualPath).Path
    }

    throw "Не найден файл: $(Join-Path $ManualPath 'Common\Media\MediaWindows64.arc')"
}

$GamePath = Resolve-GamePath $GamePath
$ArcPath = Join-Path $GamePath "Common\Media\MediaWindows64.arc"
if (-not (Test-Path -LiteralPath $ArcPath)) {
    throw "Не найден файл: $ArcPath"
}

$OriginalBackupPath = "$ArcPath.original.bak"

if ($RestoreEnglish) {
    if (-not (Test-Path -LiteralPath $OriginalBackupPath)) {
        throw "Не найден оригинальный бэкап: $OriginalBackupPath. Сначала установите русификатор этой версией установщика или восстановите файл вручную из своего бэкапа."
    }

    $BeforeRestoreBackupPath = "$ArcPath.bak-before-english-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $ArcPath -Destination $BeforeRestoreBackupPath -Force
    Copy-Item -LiteralPath $OriginalBackupPath -Destination $ArcPath -Force

    Write-Host "Готово."
    Write-Host "Английская версия восстановлена."
    Write-Host "Файл игры: $ArcPath"
    Write-Host "Бэкап русской версии перед восстановлением: $BeforeRestoreBackupPath"
    return
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("minecraft-legacy-rus-" + [guid]::NewGuid().ToString("N"))
$Downloads = Download-SourceFiles $TempDir

try {
    $IdByIndex = @{}
    foreach ($Line in [System.IO.File]::ReadLines($Downloads["Minecraft.Client/Windows64Media/strings.h"])) {
        if ($Line -match '^#define\s+(IDS_[A-Za-z0-9_]+)\s+(\d+)') {
            $IdByIndex[[int]$Matches[2]] = $Matches[1]
        }
    }

    $IndexById = @{}
    foreach ($Index in $IdByIndex.Keys) {
        $IndexById[$IdByIndex[$Index]] = $Index
    }

    $RussianXmlPaths = $Downloads.Values | Where-Object { $_ -like "*.xml" }
    $RussianMap = Load-XmlStringMap ([string[]]$RussianXmlPaths)
    $Overrides = Get-ManualOverrides

    $Arc = [System.IO.File]::ReadAllBytes($ArcPath)
    $ArcIndex = 4
    $EntryCount = Read-U32BE $Arc 0
    $ArcEntries = @()

    for ($I = 0; $I -lt $EntryCount; $I++) {
        $NameLength = Read-U16BE $Arc $ArcIndex
        $ArcIndex += 2
        $Name = [System.Text.Encoding]::ASCII.GetString($Arc, $ArcIndex, $NameLength)
        $ArcIndex += $NameLength
        $Offset = Read-U32BE $Arc $ArcIndex
        $ArcIndex += 4
        $Size = Read-U32BE $Arc $ArcIndex
        $ArcIndex += 4

        $Data = New-Object byte[] $Size
        [Array]::Copy($Arc, $Offset, $Data, 0, $Size)

        $ArcEntries += [pscustomobject]@{
            Name = $Name
            Offset = $Offset
            Size = $Size
            Data = $Data
        }
    }

    $LanguagesEntry = $ArcEntries | Where-Object { $_.Name -eq "languages.loc" } | Select-Object -First 1
    if (-not $LanguagesEntry) {
        throw "В архиве не найден languages.loc."
    }

    $Loc = $LanguagesEntry.Data
    $LocIndex = 0
    $LocVersion = Read-U32BE $Loc $LocIndex
    $LocIndex += 4
    $LanguageCount = Read-U32BE $Loc $LocIndex
    $LocIndex += 4
    $Languages = @()

    for ($I = 0; $I -lt $LanguageCount; $I++) {
        $Code = Read-Utf $Loc ([ref]$LocIndex)
        $Size = Read-U32BE $Loc $LocIndex
        $LocIndex += 4
        $Languages += [pscustomobject]@{
            Code = $Code
            Size = $Size
            Start = 0
            Data = $null
        }
    }

    $DataPosition = $LocIndex
    foreach ($Language in $Languages) {
        $Language.Start = $DataPosition
        $Data = New-Object byte[] $Language.Size
        [Array]::Copy($Loc, $DataPosition, $Data, 0, $Language.Size)
        $Language.Data = $Data
        $DataPosition += $Language.Size
    }

    $English = $Languages | Where-Object { $_.Code -eq "en-US" } | Select-Object -First 1
    if (-not $English) {
        throw "В languages.loc не найден сегмент en-US."
    }

    $EnglishValues = Read-StaticLanguageValues $English.Data
    if ($IdByIndex.Count -ne $EnglishValues.Count) {
        throw "Количество ID не совпало с количеством строк: ID=$($IdByIndex.Count), строки=$($EnglishValues.Count)."
    }

    $RussianValues = New-Object string[] $EnglishValues.Count
    $OfficialCount = 0
    $FallbackCount = 0

    for ($I = 0; $I -lt $EnglishValues.Count; $I++) {
        $Id = $IdByIndex[$I]
        if ($RussianMap.ContainsKey($Id) -and $RussianMap[$Id].Length -gt 0) {
            $RussianValues[$I] = $RussianMap[$Id]
            $OfficialCount += 1
        } else {
            $RussianValues[$I] = $EnglishValues[$I]
            $FallbackCount += 1
        }
    }

    foreach ($Id in $Overrides.Keys) {
        if ($IndexById.ContainsKey($Id)) {
            $RussianValues[$IndexById[$Id]] = $Overrides[$Id]
        }
    }

    $RussianSegment = Build-StaticLanguage "ru-RU" $RussianValues
    $ExistingRussian = $Languages | Where-Object { $_.Code -eq "ru-RU" } | Select-Object -First 1

    if ($ExistingRussian) {
        $ExistingRussian.Data = $RussianSegment
        $ExistingRussian.Size = $RussianSegment.Length
    } else {
        $Languages += [pscustomobject]@{
            Code = "ru-RU"
            Size = $RussianSegment.Length
            Start = 0
            Data = $RussianSegment
        }
    }

    if (-not $NoForceEnglishSlot) {
        $English.Data = Build-StaticLanguage "en-US" $RussianValues
        $English.Size = $English.Data.Length
    }

    $NewLoc = New-Object System.IO.MemoryStream
    Write-U32BE $NewLoc $LocVersion
    Write-U32BE $NewLoc $Languages.Count

    foreach ($Language in $Languages) {
        Write-Utf $NewLoc $Language.Code
        Write-U32BE $NewLoc $Language.Data.Length
    }

    foreach ($Language in $Languages) {
        $NewLoc.Write($Language.Data, 0, $Language.Data.Length)
    }

    $LanguagesEntry.Data = $NewLoc.ToArray()
    $LanguagesEntry.Size = $LanguagesEntry.Data.Length

    if (-not (Test-Path -LiteralPath $OriginalBackupPath)) {
        Copy-Item -LiteralPath $ArcPath -Destination $OriginalBackupPath
    }

    $BackupPath = "$ArcPath.bak-before-russian-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $ArcPath -Destination $BackupPath

    $HeaderLength = 4
    foreach ($Entry in $ArcEntries) {
        $HeaderLength += 2 + [System.Text.Encoding]::ASCII.GetByteCount($Entry.Name) + 8
    }

    $OffsetCursor = $HeaderLength
    foreach ($Entry in $ArcEntries) {
        $Entry.Offset = $OffsetCursor
        $Entry.Size = $Entry.Data.Length
        $OffsetCursor += $Entry.Size
    }

    $NewArc = New-Object System.IO.MemoryStream
    Write-U32BE $NewArc $ArcEntries.Count

    foreach ($Entry in $ArcEntries) {
        $NameBytes = [System.Text.Encoding]::ASCII.GetBytes($Entry.Name)
        Write-U16BE $NewArc $NameBytes.Length
        $NewArc.Write($NameBytes, 0, $NameBytes.Length)
        Write-U32BE $NewArc $Entry.Offset
        Write-U32BE $NewArc $Entry.Size
    }

    foreach ($Entry in $ArcEntries) {
        $NewArc.Write($Entry.Data, 0, $Entry.Data.Length)
    }

    [System.IO.File]::WriteAllBytes($ArcPath, $NewArc.ToArray())

    Write-Host "Готово."
    Write-Host "Файл игры: $ArcPath"
    Write-Host "Оригинальный английский бэкап: $OriginalBackupPath"
    Write-Host "Резервная копия: $BackupPath"
    Write-Host "Русских строк из источников: $OfficialCount"
    Write-Host "Английских запасных строк: $FallbackCount"
    if (-not $NoForceEnglishSlot) {
        Write-Host "Слот en-US принудительно заменён русским переводом."
    } else {
        Write-Host "Слот en-US не изменялся."
    }
}
finally {
    if (Test-Path -LiteralPath $TempDir) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force
    }
}
