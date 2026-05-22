138
  "WPFTweaksLocation": {
139
    "Content": "Location Tracking - Disable",
140
    "Description": "Disables Location Tracking.",
141
    "category": "Essential Tweaks",
142
    "panel": "1",
143
    "service": [
144
      {
145
        "Name": "lfsvc",
146
        "StartupType": "Disable",
147
        "OriginalType": "Manual"
148
      }
149
    ],
150
    "registry": [
151
      {
152
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location",
153
        "Name": "Value",
154
        "Value": "Deny",
155
        "Type": "String",
156
        "OriginalValue": "Allow"
157
      },
158
      {
159
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Sensor\\Overrides\\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}",
160
        "Name": "SensorPermissionState",
161
        "Value": "0",
162
        "Type": "DWord",
163
        "OriginalValue": "1"
164
      },
165
      {
166
        "Path": "HKLM:\\SYSTEM\\Maps",
167
        "Name": "AutoUpdateEnabled",
168
        "Value": "0",
169
        "Type": "DWord",
170
        "OriginalValue": "1"
171
      }
172
    ],