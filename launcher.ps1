$tmp = "$env:TEMP\HksUtil"
mkdir $tmp -Force | Out-Null
$base = "https://raw.githubusercontent.com/hartkitsak/HksUtil/main"
iwr -Uri "$base/app.ps1" -OutFile "$tmp\app.ps1"
iwr -Uri "$base/ui.xaml" -OutFile "$tmp\ui.xaml"
mkdir "$tmp\config" -Force | Out-Null
@("apps","dns","features","preferences","themes","tweaks") | ForEach-Object {
  iwr -Uri "$base/config/$_.json" -OutFile "$tmp\config\$_.json"
}
& "$tmp\app.ps1"
