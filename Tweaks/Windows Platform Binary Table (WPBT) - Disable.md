974
  "WPFTweaksWPBT": {
975
    "Content": "Windows Platform Binary Table (WPBT) - Disable",
976
    "Description": "If enabled, WPBT allows your computer vendor to execute programs at boot time, such as anti-theft software, software drivers, as well as force install software without user consent. Poses potential security risk.",
977
    "category": "Essential Tweaks",
978
    "panel": "1",
979
    "registry": [
980
      {
981
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager",
982
        "Name": "DisableWpbtExecution",
983
        "Value": "1",
984
        "Type": "DWord",
985
        "OriginalValue": "<RemoveEntry>"
986
      }
987
    ],