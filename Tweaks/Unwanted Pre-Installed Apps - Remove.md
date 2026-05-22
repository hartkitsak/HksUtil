821
  "WPFTweaksDeBloat": {
822
    "Content": "Unwanted Pre-Installed Apps - Remove",
823
    "Description": "This will remove a bunch of Windows pre-installed applications which most people dont want on their system.",
824
    "category": "Essential Tweaks",
825
    "panel": "1",
826
    "appx": [
827
      "Microsoft.WindowsFeedbackHub",
828
      "Microsoft.BingNews",
829
      "Microsoft.BingSearch",
830
      "Microsoft.BingWeather",
831
      "Clipchamp.Clipchamp",
832
      "Microsoft.Todos",
833
      "Microsoft.PowerAutomateDesktop",
834
      "Microsoft.MicrosoftSolitaireCollection",
835
      "Microsoft.WindowsSoundRecorder",
836
      "Microsoft.MicrosoftStickyNotes",
837
      "Microsoft.Windows.DevHome",
838
      "Microsoft.Paint",
839
      "Microsoft.OutlookForWindows",
840
      "Microsoft.WindowsAlarms",
841
      "Microsoft.StartExperiencesApp",
842
      "Microsoft.GetHelp",
843
      "Microsoft.ZuneMusic",
844
      "MicrosoftCorporationII.QuickAssist",
845
      "MSTeams"
846
    ],
847
    "InvokeScript": [
848
      "
849
      $TeamsPath = \"$Env:LocalAppData\\Microsoft\\Teams\\Update.exe\"
850

851
      if (Test-Path $TeamsPath) {
852
        Write-Host \"Uninstalling Teams\"
853
        Start-Process $TeamsPath -ArgumentList -uninstall -wait
854

855
        Write-Host \"Deleting Teams directory\"
856
        Remove-Item $TeamsPath -Recurse -Force
857
      }
858
      "
859
    ],