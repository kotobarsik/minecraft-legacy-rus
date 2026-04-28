# Troubleshooting

## Ручной запуск установки

Если нужно указать путь вручную, откройте PowerShell в папке русификатора и запустите:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -GamePath "C:\Games\LCEWindows64"
```

## Только добавить `ru-RU`

По умолчанию установщик заменяет слот `en-US` русскими строками. Это помогает сборкам, где меню выбора языка скрыто или отключено.

Если нужно только добавить `ru-RU`, без замены английского слота:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -GamePath "C:\Games\LCEWindows64" -NoForceEnglishSlot
```

## Ручной возврат английского

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -GamePath "C:\Games\LCEWindows64" -RestoreEnglish
```

Восстановление использует файл:

```text
LCEWindows64\Common\Media\MediaWindows64.arc.original.bak
```

Он создаётся рядом с `MediaWindows64.arc` при первой установке русского.
