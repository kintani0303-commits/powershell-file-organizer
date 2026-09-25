@echo off
rem ============================================================
rem  テストファイル自動生成 起動用バッチファイル
rem  このファイルをダブルクリックするだけで、
rem  このbatファイルと同じ階層に「TestData」フォルダが作られ、
rem  その中にダミーファイルが自動生成されます。
rem ============================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Create-TestFiles.ps1" -TargetFolder "%~dp0TestData" -Reset

echo.
echo テストファイルの作成が完了しました。
echo 「TestData」フォルダの中身を確認してください。
pause
