175
  "WPFTweaksServices": {
176
    "Content": "Services - Set to Manual",
177
    "Description": "Sets some services to Manual startup and adjusts the SvcHostSplitThresholdInKB registry value to better match system memory, which can significantly reduce the number of svchost.exe processes.",
178
    "category": "Essential Tweaks",
179
    "panel": "1",
180
    "service": [
181
      {
182
        "Name": "CscService",
183
        "StartupType": "Disabled",
184
        "OriginalType": "Manual"
185
      },
186
      {
187
        "Name": "DiagTrack",
188
        "StartupType": "Disabled",
189
        "OriginalType": "Automatic"
190
      },
191
      {
192
        "Name": "MapsBroker",
193
        "StartupType": "Manual",
194
        "OriginalType": "Automatic"
195
      },
196
      {
197
        "Name": "StorSvc",
198
        "StartupType": "Manual",
199
        "OriginalType": "Automatic"
200
      },
201
      {
202
        "Name": "SharedAccess",
203
        "StartupType": "Disabled",
204
        "OriginalType": "Automatic"
205
      }
206
    ],
207
    "InvokeScript": [
208
      "
209
      $Memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB
210
      Set-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name SvcHostSplitThresholdInKB -Value $Memory
211
      "
212
    ],