@echo off
setlocal

REM このバッチファイルが置かれているフォルダ（＝プロジェクトルート）に移動
cd /d "%~dp0"

echo ============================================
echo  Flutter Web ビルド ＋ docs 反映 ＋ Git push
echo  リポジトリ: smadan02 （giun0721-byte）
echo ============================================
echo.

REM 1) Flutter Web ビルド
echo [1/4] Flutter Web をビルド中...
flutter build web --release --base-href "/smadan02/"
if errorlevel 1 (
    echo Flutter build でエラーが発生しました。
    pause
    goto :eof
)

REM 2) docs フォルダを全消去（なければ作成）
echo [2/4] docs フォルダを初期化中...

if not exist docs (
    mkdir docs
) else (
    del /q "docs\*.*" 2>nul
    for /d %%D in ("docs\*") do rmdir /s /q "%%D"
)

REM 3) build/web → docs へコピー
echo [3/4] build\web の内容を docs にコピー中...

REM robocopy を使う（Windows標準）
robocopy "build\web" "docs" /E >nul

REM robocopy の戻り値が 8 以上ならエラー扱い
if errorlevel 8 (
    echo ファイルコピー中にエラーが発生しました。
    pause
    goto :eof
)

REM 4) Git へコミット ＆ push
echo [4/4] Git への反映を行います。
echo.

git status

echo.
set /p COMMIT_MSG=コミットメッセージを入力してください（例: fix effect / enterで中止）: 

if "%COMMIT_MSG%"=="" (
    echo コミットは行わず終了します。
    pause
    goto :eof
)

echo 変更をステージングしています...
git add .

echo コミットしています...
git commit -m "%COMMIT_MSG%"

if errorlevel 1 (
    echo git commit でエラーが発生しました。
    pause
    goto :eof
)

echo リモートへ push 中...
git push

if errorlevel 1 (
    echo git push でエラーが発生しました。
    pause
    goto :eof
)

echo.
echo ============================================
echo  デプロイ完了！ GitHub Pages も少し待てば更新されます。
echo  URL: https://giun0721-byte.github.io/smadan02/
echo ============================================
echo.
pause
endlocal
