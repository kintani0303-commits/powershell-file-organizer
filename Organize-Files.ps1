<#
.SYNOPSIS
    指定フォルダ内のファイルを自動で振り分け・リネームする汎用ツール。

.DESCRIPTION
    3つのモードに対応:
      - ByExtension : 拡張子ごとにサブフォルダへ振り分け
      - ByDate      : 更新日(年-月)ごとにサブフォルダへ振り分け
      - Rename      : 指定パターンで連番リネーム

    実際に移動・リネームする前に -DryRun スイッチで
    「何がどう変わるか」だけを確認できる(誤操作防止)。
    処理内容はすべてログファイルに記録される。

.PARAMETER SourceFolder
    処理対象のフォルダパス。

.PARAMETER Mode
    ByExtension / ByDate / Rename のいずれか。

.PARAMETER RenamePattern
    Mode が Rename のときに使う命名パターン。
    {name} = 元のファイル名(拡張子なし) / {ext} = 拡張子 / {n} = 連番 / {date} = 更新日(yyyyMMdd)
    例: "Invoice_{date}_{n}{ext}"

.PARAMETER DestinationFolder
    振り分け先フォルダ。省略時は SourceFolder 内にサブフォルダを作成する。

.PARAMETER DryRun
    実際には移動・リネームせず、予定される変更内容のみを表示する。

.PARAMETER LogPath
    ログファイルの出力先。省略時は SourceFolder 内に organize-log_yyyyMMdd_HHmmss.csv を作成。

.EXAMPLE
    # 拡張子ごとに振り分け(まずはドライランで確認)
    .\Organize-Files.ps1 -SourceFolder "C:\Downloads" -Mode ByExtension -DryRun

.EXAMPLE
    # 更新日(年-月)ごとに振り分けて実行
    .\Organize-Files.ps1 -SourceFolder "C:\Downloads" -Mode ByDate

.EXAMPLE
    # 請求書PDFを部署別フォルダへ、日付付きで連番リネームしながら移動
    .\Organize-Files.ps1 -SourceFolder "C:\Invoices" -Mode Rename -RenamePattern "Invoice_{date}_{n}{ext}"

.NOTES
    PowerShell 5.1 / 7 以降で動作確認。追加モジュール不要。
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [ValidateSet("ByExtension", "ByDate", "Rename")]
    [string]$Mode,

    [string]$RenamePattern = "{name}_{n}{ext}",

    [string]$DestinationFolder,

    [switch]$DryRun,

    [string]$LogPath
)

# ---------- 事前チェック ----------
if (-not (Test-Path -LiteralPath $SourceFolder)) {
    Write-Error "指定されたフォルダが見つかりません: $SourceFolder"
    exit 1
}

$SourceFolder = (Resolve-Path -LiteralPath $SourceFolder).Path

if (-not $DestinationFolder) {
    $DestinationFolder = $SourceFolder
}

if (-not $LogPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogPath = Join-Path $SourceFolder "organize-log_$timestamp.csv"
}

$logEntries = New-Object System.Collections.Generic.List[object]

function Write-Log {
    param($Action, $Original, $New, $Status)
    $logEntries.Add([PSCustomObject]@{
        Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Action      = $Action
        OriginalPath = $Original
        NewPath     = $New
        Status      = $Status
    })
}

# ---------- 対象ファイル取得(サブフォルダは対象外・直下のファイルのみ) ----------
$files = Get-ChildItem -LiteralPath $SourceFolder -File

if ($files.Count -eq 0) {
    Write-Host "対象ファイルが見つかりませんでした。" -ForegroundColor Yellow
    exit 0
}

Write-Host "対象ファイル数: $($files.Count) 件 / モード: $Mode / DryRun: $($DryRun.IsPresent)" -ForegroundColor Cyan

# 連番管理用(拡張子・グループごとにカウント)
$counterMap = @{}

foreach ($file in $files) {

    switch ($Mode) {

        "ByExtension" {
            $ext = if ($file.Extension) { $file.Extension.TrimStart(".").ToLower() } else { "no_extension" }
            $targetDir = Join-Path $DestinationFolder $ext
            $targetPath = Join-Path $targetDir $file.Name

            if (-not (Test-Path $targetDir) -and -not $DryRun) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            if ($DryRun) {
                Write-Host "[DRYRUN] $($file.Name)  ->  $targetDir\" -ForegroundColor DarkYellow
                Write-Log "Move(DryRun)" $file.FullName $targetPath "Simulated"
            }
            else {
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
                    Write-Host "移動完了: $($file.Name) -> $ext\" -ForegroundColor Green
                    Write-Log "Move" $file.FullName $targetPath "Success"
                }
                catch {
                    Write-Host "失敗: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log "Move" $file.FullName $targetPath "Failed: $($_.Exception.Message)"
                }
            }
        }

        "ByDate" {
            $yearMonth = $file.LastWriteTime.ToString("yyyy-MM")
            $targetDir = Join-Path $DestinationFolder $yearMonth
            $targetPath = Join-Path $targetDir $file.Name

            if (-not (Test-Path $targetDir) -and -not $DryRun) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            if ($DryRun) {
                Write-Host "[DRYRUN] $($file.Name)  ->  $targetDir\" -ForegroundColor DarkYellow
                Write-Log "Move(DryRun)" $file.FullName $targetPath "Simulated"
            }
            else {
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
                    Write-Host "移動完了: $($file.Name) -> $yearMonth\" -ForegroundColor Green
                    Write-Log "Move" $file.FullName $targetPath "Success"
                }
                catch {
                    Write-Host "失敗: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log "Move" $file.FullName $targetPath "Failed: $($_.Exception.Message)"
                }
            }
        }

        "Rename" {
            $ext = $file.Extension
            $nameOnly = $file.BaseName
            $dateStr = $file.LastWriteTime.ToString("yyyyMMdd")

            # 連番はパターン内の {n} の有無にかかわらずグループ管理(拡張子単位)
            $groupKey = $ext
            if (-not $counterMap.ContainsKey($groupKey)) {
                $counterMap[$groupKey] = 1
            }
            $n = $counterMap[$groupKey]
            $counterMap[$groupKey]++

            $newName = $RenamePattern `
                -replace '\{name\}', $nameOnly `
                -replace '\{ext\}', $ext `
                -replace '\{n\}', ("{0:D3}" -f $n) `
                -replace '\{date\}', $dateStr

            $targetPath = Join-Path $DestinationFolder $newName

            if ($DryRun) {
                Write-Host "[DRYRUN] $($file.Name)  ->  $newName" -ForegroundColor DarkYellow
                Write-Log "Rename(DryRun)" $file.FullName $targetPath "Simulated"
            }
            else {
                try {
                    if ($DestinationFolder -ne $SourceFolder -and -not (Test-Path $DestinationFolder)) {
                        New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
                    }
                    Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
                    Write-Host "リネーム完了: $($file.Name) -> $newName" -ForegroundColor Green
                    Write-Log "Rename" $file.FullName $targetPath "Success"
                }
                catch {
                    Write-Host "失敗: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                    Write-Log "Rename" $file.FullName $targetPath "Failed: $($_.Exception.Message)"
                }
            }
        }
    }
}

# ---------- ログ出力 ----------
$logEntries | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
Write-Host "`n処理完了。ログを出力しました: $LogPath" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "※ DryRun のため実際のファイル操作は行われていません。-DryRun を外すと実行されます。" -ForegroundColor Yellow
}
