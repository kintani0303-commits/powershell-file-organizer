<#
.SYNOPSIS
    Organize-Files.ps1 の動作確認用に、ダミーファイルを自動生成する。

.DESCRIPTION
    拡張子違い・更新日違いのダミーファイルをまとめて作成する。
    ByExtension / ByDate / Rename のどのモードのテストにも使える。

.PARAMETER TargetFolder
    ダミーファイルを作成するフォルダ。存在しなければ自動作成する。

.PARAMETER Count
    作成するファイル数(既定: 15)。

.PARAMETER Reset
    実行前に TargetFolder の中身を空にする(既存のテストファイルを一掃してから作り直したい場合)。

.EXAMPLE
    # C:\Test に15個のダミーファイルを作成
    .\Create-TestFiles.ps1 -TargetFolder "C:\Test"

.EXAMPLE
    # 既存のテストファイルを消してから30個作り直す
    .\Create-TestFiles.ps1 -TargetFolder "C:\Test" -Count 30 -Reset

.NOTES
    作成されるファイルは中身が空(または数行のダミーテキスト)のテスト専用ファイルです。
    実データが入っているフォルダには絶対に指定しないでください。
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [int]$Count = 15,

    [switch]$Reset
)

# ---------- 安全チェック ----------
# システムフォルダなど、間違って指定しがちな危険なパスをブロック
$dangerousPaths = @(
    $env:WINDIR,
    "$env:SystemDrive\",
    "$env:SystemDrive\Windows",
    "$env:SystemDrive\Program Files",
    "$env:SystemDrive\Program Files (x86)"
)
$resolvedTarget = $TargetFolder.TrimEnd('\')
foreach ($dp in $dangerousPaths) {
    if ($resolvedTarget -ieq $dp.TrimEnd('\')) {
        Write-Error "危険な可能性があるフォルダが指定されました。処理を中止します: $TargetFolder"
        exit 1
    }
}

# ---------- フォルダ準備 ----------
if (-not (Test-Path -LiteralPath $TargetFolder)) {
    New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    Write-Host "フォルダを作成しました: $TargetFolder" -ForegroundColor Cyan
}

if ($Reset) {
    Write-Host "既存ファイルを削除しています..." -ForegroundColor Yellow
    Get-ChildItem -LiteralPath $TargetFolder -File | Remove-Item -Force
}

# ---------- ダミーファイル生成 ----------
# 拡張子ごとのサンプル名(それらしいファイル名にして、実際の業務データに近づける)
$fileTemplates = @(
    @{ Name = "invoice";      Ext = ".pdf" },
    @{ Name = "report";       Ext = ".pdf" },
    @{ Name = "contract";     Ext = ".pdf" },
    @{ Name = "photo";        Ext = ".jpg" },
    @{ Name = "screenshot";   Ext = ".png" },
    @{ Name = "memo";         Ext = ".txt" },
    @{ Name = "notes";        Ext = ".txt" },
    @{ Name = "budget";       Ext = ".xlsx" },
    @{ Name = "summary";      Ext = ".xlsx" },
    @{ Name = "proposal";     Ext = ".docx" },
    @{ Name = "data";         Ext = ".csv" },
    @{ Name = "export";       Ext = ".csv" },
    @{ Name = "archive";      Ext = ".zip" },
    @{ Name = "readme";       Ext = "" }        # 拡張子なしファイルのテスト用
)

$createdFiles = New-Object System.Collections.Generic.List[string]

for ($i = 1; $i -le $Count; $i++) {
    $template = $fileTemplates[($i - 1) % $fileTemplates.Count]
    $fileName = "$($template.Name)_$i$($template.Ext)"
    $filePath = Join-Path $TargetFolder $fileName

    # ByDateモードのテストになるよう、更新日を過去1年の範囲でランダムにばらけさせる
    $randomDaysAgo = Get-Random -Minimum 0 -Maximum 365
    $fakeDate = (Get-Date).AddDays(-$randomDaysAgo)

    "これはテスト用のダミーファイルです。作成日時: $(Get-Date)" | Out-File -FilePath $filePath -Encoding UTF8

    # 作成日時・更新日時をランダムな日付に書き換える(ByDateモードのテスト用)
    (Get-Item $filePath).LastWriteTime = $fakeDate
    (Get-Item $filePath).CreationTime = $fakeDate

    $createdFiles.Add($fileName)
    Write-Host "作成: $fileName  (更新日: $($fakeDate.ToString('yyyy-MM-dd')))" -ForegroundColor Green
}

Write-Host "`n完了しました。$($createdFiles.Count) 件のテストファイルを作成しました。" -ForegroundColor Cyan
Write-Host "フォルダ: $TargetFolder" -ForegroundColor Cyan
