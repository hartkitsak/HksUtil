$tmp = "$env:TEMP\HksUtil"
mkdir $tmp -Force | Out-Null
$zip = "$tmp\repo.zip"
iwr -Uri "https://github.com/hartkitsak/HksUtil/archive/main.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath $tmp -Force
& "$tmp\HksUtil-main\app.ps1"
