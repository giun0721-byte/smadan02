flutter build web --release --base-href "/smadan02/"

Remove-Item docs\* -Recurse -Force
Copy-Item build\web\* docs\ -Recurse -Force

git add .
git commit -m "Daily update"
git push
