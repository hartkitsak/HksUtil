 2
  "WPFTweaksActivity": {
 3
    "Content": "Activity History - Disable",
 4
    "Description": "Erases recent docs, clipboard, and run history.",
 5
    "category": "Essential Tweaks",
 6
    "panel": "1",
 7
    "registry": [
 8
      {
 9
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
10
        "Name": "EnableActivityFeed",
11
        "Value": "0",
12
        "Type": "DWord",
13
        "OriginalValue": "<RemoveEntry>"
14
      },
15
      {
16
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
17
        "Name": "PublishUserActivities",
18
        "Value": "0",
19
        "Type": "DWord",
20
        "OriginalValue": "<RemoveEntry>"
21
      },
22
      {
23
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
24
        "Name": "UploadUserActivities",
25
        "Value": "0",
26
        "Type": "DWord",
27
        "OriginalValue": "<RemoveEntry>"
28
      }
29
    ],