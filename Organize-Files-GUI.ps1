<#
.SYNOPSIS
    Organize-Files.ps1 のGUIランチャー。
    フォルダ選択・モード切替・ドライラン確認をボタン操作だけで行えるようにする。

.DESCRIPTION
    コマンド操作に不慣れなクライアント向けの簡易フォーム。
    実際の処理ロジックは Organize-Files.ps1 側にあり、
    このスクリプトはパラメータをGUIで組み立てて呼び出すだけの「ラッパー」。

.NOTES
    Organize-Files.ps1 と同じフォルダに置いて実行してください。
    実行: .\Organize-Files-GUI.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot
$targetScript = Join-Path $scriptDir "Organize-Files.ps1"

if (-not (Test-Path $targetScript)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Organize-Files.ps1 が見つかりません。`n同じフォルダに配置してください。`n($targetScript)",
        "エラー", "OK", "Error"
    ) | Out-Null
    exit 1
}

# ---------- フォーム本体 ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "ファイル整理ツール"
$form.Size = New-Object System.Drawing.Size(560, 505)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# --- 対象フォルダ ---
$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "対象フォルダ:"
$lblSource.Location = New-Object System.Drawing.Point(15, 20)
$lblSource.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblSource)

$txtSource = New-Object System.Windows.Forms.TextBox
$txtSource.Location = New-Object System.Drawing.Point(120, 18)
$txtSource.Size = New-Object System.Drawing.Size(320, 20)
$form.Controls.Add($txtSource)

$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Text = "参照..."
$btnBrowseSource.Location = New-Object System.Drawing.Point(450, 16)
$btnBrowseSource.Size = New-Object System.Drawing.Size(80, 24)
$btnBrowseSource.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") {
        $txtSource.Text = $dlg.SelectedPath
    }
})
$form.Controls.Add($btnBrowseSource)

# --- 振り分け先フォルダ(任意) ---
$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text = "振り分け先(任意):"
$lblDest.Location = New-Object System.Drawing.Point(15, 55)
$lblDest.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblDest)

$txtDest = New-Object System.Windows.Forms.TextBox
$txtDest.Location = New-Object System.Drawing.Point(120, 53)
$txtDest.Size = New-Object System.Drawing.Size(320, 20)
$form.Controls.Add($txtDest)

$btnBrowseDest = New-Object System.Windows.Forms.Button
$btnBrowseDest.Text = "参照..."
$btnBrowseDest.Location = New-Object System.Drawing.Point(450, 51)
$btnBrowseDest.Size = New-Object System.Drawing.Size(80, 24)
$btnBrowseDest.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") {
        $txtDest.Text = $dlg.SelectedPath
    }
})
$form.Controls.Add($btnBrowseDest)

# --- モード選択 ---
$lblMode = New-Object System.Windows.Forms.Label
$lblMode.Text = "処理モード:"
$lblMode.Location = New-Object System.Drawing.Point(15, 92)
$lblMode.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblMode)

$cmbMode = New-Object System.Windows.Forms.ComboBox
$cmbMode.Location = New-Object System.Drawing.Point(120, 90)
$cmbMode.Size = New-Object System.Drawing.Size(200, 20)
$cmbMode.DropDownStyle = "DropDownList"
$cmbMode.Items.AddRange(@(
    "ByExtension（拡張子別に振り分け）",
    "ByDate（更新日別に振り分け）",
    "Rename（命名パターンでリネーム）"
))
$cmbMode.SelectedIndex = 0
$form.Controls.Add($cmbMode)

# --- リネームパターン(Renameモード時のみ有効) ---
$lblPattern = New-Object System.Windows.Forms.Label
$lblPattern.Text = "命名パターン:"
$lblPattern.Location = New-Object System.Drawing.Point(15, 127)
$lblPattern.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblPattern)

$txtPattern = New-Object System.Windows.Forms.TextBox
$txtPattern.Location = New-Object System.Drawing.Point(120, 125)
$txtPattern.Size = New-Object System.Drawing.Size(320, 20)
$txtPattern.Text = "{name}_{n}{ext}"
$txtPattern.Enabled = $false
$form.Controls.Add($txtPattern)

# --- 記号を挿入できるクイックボタン(覚えなくてもクリックで入力できる) ---
$patternButtons = @(
    @{ Text = "元の名前"; Code = "{name}" },
    @{ Text = "拡張子";   Code = "{ext}" },
    @{ Text = "連番";     Code = "{n}" },
    @{ Text = "日付";     Code = "{date}" }
)

$btnX = 120
foreach ($pb in $patternButtons) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "$($pb.Text) [$($pb.Code)]"
    $b.Location = New-Object System.Drawing.Point($btnX, 149)
    $b.Size = New-Object System.Drawing.Size(95, 24)
    $b.Font = New-Object System.Drawing.Font($b.Font.FontFamily, 8)
    $code = $pb.Code
    $b.Add_Click({
        # カーソル位置に記号を挿入(選択中なら選択範囲を置き換え)
        $pos = $txtPattern.SelectionStart
        $txtPattern.Text = $txtPattern.Text.Insert($pos, $code)
        $txtPattern.SelectionStart = $pos + $code.Length
        $txtPattern.Focus()
    }.GetNewClosure())
    $form.Controls.Add($b)
    $btnX += 100
}

# --- 変換後の見た目をその場でプレビュー ---
$lblPreviewCaption = New-Object System.Windows.Forms.Label
$lblPreviewCaption.Text = "変換例:"
$lblPreviewCaption.Location = New-Object System.Drawing.Point(15, 180)
$lblPreviewCaption.Size = New-Object System.Drawing.Size(100, 32)
$form.Controls.Add($lblPreviewCaption)

$lblPreview = New-Object System.Windows.Forms.Label
$lblPreview.Location = New-Object System.Drawing.Point(120, 178)
$lblPreview.Size = New-Object System.Drawing.Size(415, 32)
$lblPreview.BorderStyle = "FixedSingle"
$lblPreview.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$lblPreview.TextAlign = "MiddleLeft"
$lblPreview.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
$lblPreview.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($lblPreview)

function Update-PatternPreview {
    # サンプル値(元ファイル: sample_report.pdf、更新日は今日)で変換結果を仮計算して表示
    $sampleName = "sample_report"
    $sampleExt = ".pdf"
    $sampleDate = (Get-Date).ToString("yyyyMMdd")
    $sampleN = "001"

    $preview = $txtPattern.Text `
        -replace '\{name\}', $sampleName `
        -replace '\{ext\}', $sampleExt `
        -replace '\{n\}', $sampleN `
        -replace '\{date\}', $sampleDate

    if ([string]::IsNullOrWhiteSpace($preview)) {
        $lblPreview.Text = "(パターンを入力してください)"
        $lblPreview.ForeColor = [System.Drawing.Color]::Gray
    }
    elseif ($preview -notmatch '\.\w+$') {
        $lblPreview.Text = "sample_report.pdf  ->  $preview   ※拡張子(.pdf等)が付きません"
        $lblPreview.ForeColor = [System.Drawing.Color]::Red
    }
    else {
        $lblPreview.Text = "sample_report.pdf  ->  $preview"
        $lblPreview.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 0)
    }
}

$txtPattern.Add_TextChanged({ Update-PatternPreview })
Update-PatternPreview

$cmbMode.Add_SelectedIndexChanged({
    $isRename = ($cmbMode.SelectedIndex -eq 2)
    $txtPattern.Enabled = $isRename
    $lblPreviewCaption.Visible = $isRename
    $lblPreview.Visible = $isRename
})
# 初期表示(デフォルトはByExtensionなのでRename専用UIは隠しておく)
$lblPreviewCaption.Visible = $false
$lblPreview.Visible = $false

# --- ドライラン チェック ---
$chkDryRun = New-Object System.Windows.Forms.CheckBox
$chkDryRun.Text = "ドライラン（実際には変更せず、結果だけ確認する）"
$chkDryRun.Location = New-Object System.Drawing.Point(120, 220)
$chkDryRun.Size = New-Object System.Drawing.Size(400, 20)
$chkDryRun.Checked = $true
$form.Controls.Add($chkDryRun)

# --- 実行ボタン ---
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "実行"
$btnRun.Location = New-Object System.Drawing.Point(120, 250)
$btnRun.Size = New-Object System.Drawing.Size(100, 32)
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnRun.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($btnRun)

# --- 結果表示ボックス ---
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "実行結果:"
$lblOutput.Location = New-Object System.Drawing.Point(15, 295)
$lblOutput.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(15, 317)
$txtOutput.Size = New-Object System.Drawing.Size(515, 140)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.ReadOnly = $true
$txtOutput.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtOutput)

# ---------- 実行処理 ----------
$btnRun.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtSource.Text) -or -not (Test-Path $txtSource.Text)) {
        [System.Windows.Forms.MessageBox]::Show("対象フォルダを正しく指定してください。", "入力エラー", "OK", "Warning") | Out-Null
        return
    }

    $modeMap = @{ 0 = "ByExtension"; 1 = "ByDate"; 2 = "Rename" }
    $mode = $modeMap[$cmbMode.SelectedIndex]

    # ハッシュテーブルでパラメータを組み立て、スプラッティングで安全に渡す
    # (文字列連結やInvoke-Expressionを使わないので、フォルダ名にスペースや
    #  特殊文字が含まれていても安全)
    $scriptParams = @{
        SourceFolder = $txtSource.Text
        Mode         = $mode
    }

    if (-not [string]::IsNullOrWhiteSpace($txtDest.Text)) {
        $scriptParams["DestinationFolder"] = $txtDest.Text
    }

    if ($mode -eq "Rename") {
        $scriptParams["RenamePattern"] = $txtPattern.Text
    }

    if ($chkDryRun.Checked) {
        $scriptParams["DryRun"] = $true
    }

    # ログの出力先をGUI側で明示的に指定しておく(実行後に読み込んでサマリーを作るため)
    $logFileName = "organize-log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv"
    $logFullPath = Join-Path $env:TEMP $logFileName
    $scriptParams["LogPath"] = $logFullPath

    $btnRun.Enabled = $false
    $txtOutput.Text = "処理を実行しています...`r`n"
    $form.Refresh()

    try {
        # *>&1 で「すべてのストリーム」(標準出力・エラー・警告・Write-Host等)を
        # 成功ストリームにまとめて捕まえる。2>&1 だけだとエラー以外は
        # 別ストリーム扱いになり、Write-Host の内容が拾えないため。
        $rawOutput = & $targetScript @scriptParams *>&1 | Out-String

        # ログCSVから件数サマリーを作成
        $summaryText = ""
        if (Test-Path $logFullPath) {
            $logRows = Import-Csv -Path $logFullPath
            $successCount = ($logRows | Where-Object { $_.Status -eq "Success" }).Count
            $simulatedCount = ($logRows | Where-Object { $_.Status -eq "Simulated" }).Count
            $failedCount = ($logRows | Where-Object { $_.Status -like "Failed*" }).Count

            $summaryLines = New-Object System.Collections.Generic.List[string]
            $summaryLines.Add("========== 実行結果サマリー ==========")
            if ($chkDryRun.Checked) {
                $summaryLines.Add("モード: ドライラン(シミュレーションのみ、実際の変更なし)")
                $summaryLines.Add("対象件数: $simulatedCount 件")
            }
            else {
                $summaryLines.Add("成功: $successCount 件")
                if ($failedCount -gt 0) {
                    $summaryLines.Add("失敗: $failedCount 件")
                }
            }
            $summaryLines.Add("ログファイル: $logFullPath")
            $summaryLines.Add("=======================================")
            $summaryLines.Add("")
            $summaryText = ($summaryLines -join "`r`n") + "`r`n"
        }

        $txtOutput.Text = $summaryText + $rawOutput

        # 完了通知(件数付き)をポップアップでも表示
        if ($chkDryRun.Checked) {
            [System.Windows.Forms.MessageBox]::Show(
                "ドライランが完了しました。`n対象件数: $simulatedCount 件`n`n内容を確認のうえ、問題なければドライランのチェックを外して実行してください。",
                "完了", "OK", "Information"
            ) | Out-Null
        }
        elseif ($failedCount -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "処理が完了しました。`n成功: $successCount 件 / 失敗: $failedCount 件`n`n詳細は結果欄をご確認ください。",
                "完了(一部失敗あり)", "OK", "Warning"
            ) | Out-Null
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "処理が完了しました。`n成功: $successCount 件",
                "完了", "OK", "Information"
            ) | Out-Null
        }
    }
    catch {
        $txtOutput.Text = "エラーが発生しました:`r`n$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            "処理中にエラーが発生しました。`n$($_.Exception.Message)",
            "エラー", "OK", "Error"
        ) | Out-Null
    }
    finally {
        $btnRun.Enabled = $true
    }
})

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
