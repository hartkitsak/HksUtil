459
  "WPFTweaksConsumerFeatures": {
460
    "Content": "ConsumerFeatures - Disable",
461
    "Description": "Windows will not automatically install any games, third-party apps, or application links from the Windows Store for the signed-in user. Some default Apps will be inaccessible (eg. Phone Link).",
462
    "category": "Essential Tweaks",
463
    "panel": "1",
464
    "registry": [
465
      {
466
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent",
467
        "Name": "DisableWindowsConsumerFeatures",
468
        "Value": "1",
469
        "Type": "DWord",
470
        "OriginalValue": "<RemoveEntry>"
471
      }
472
    ],