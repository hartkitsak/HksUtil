1119
  "WPFTweaksDeleteTempFiles": {
1120
    "Content": "Temporary Files - Remove",
1121
    "Description": "Erases TEMP Folders.",
1122
    "category": "Essential Tweaks",
1123
    "panel": "1",
1124
    "InvokeScript": [
1125
      "
1126
      Remove-Item -Path \"$Env:Temp\\*\" -Recurse -Force
1127
      Remove-Item -Path \"$Env:SystemRoot\\Temp\\*\" -Recurse -Force
1128
      "
1129
    ],