1106
  "WPFTweaksDiskCleanup": {
1107
    "Content": "Disk Cleanup - Run",
1108
    "Description": "Runs Disk Cleanup on Drive C: and removes old Windows Updates.",
1109
    "category": "Essential Tweaks",
1110
    "panel": "1",
1111
    "InvokeScript": [
1112
      "
1113
      cleanmgr.exe /d C: /VERYLOWDISK
1114
      Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
1115
      "
1116
    ],