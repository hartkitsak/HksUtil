61
  "WPFTweaksWidget": {
62
    "Content": "Widgets - Remove",
63
    "Description": "Removes the annoying widgets in the bottom left of the Taskbar.",
64
    "category": "Essential Tweaks",
65
    "panel": "1",
66
    "InvokeScript": [
67
      "
68
      # Sometimes if you dont stop the Widgets process the removal may fail
69

70
      Get-Process *Widget* | Stop-Process
71
      Get-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers
72
      Get-AppxPackage MicrosoftWindows.Client.WebExperience -AllUsers | Remove-AppxPackage -AllUsers
73

74
      Invoke-WinUtilExplorerUpdate -action \"restart\"
75
      Write-Host \"Removed widgets\"
76
      "
77
    ],
78
    "UndoScript": [
79
      "
80
      Write-Host \"Restoring widgets AppxPackages\"
81

82
      Add-AppxPackage -Register \"C:\\Program Files\\WindowsApps\\Microsoft.WidgetsPlatformRuntime*\\AppxManifest.xml\" -DisableDevelopmentMode
83
      Add-AppxPackage -Register \"C:\\Program Files\\WindowsApps\\MicrosoftWindows.Client.WebExperience*\\AppxManifest.xml\" -DisableDevelopmentMode
84

85
      Invoke-WinUtilExplorerUpdate -action \"restart\"
86
      "
87
    ],