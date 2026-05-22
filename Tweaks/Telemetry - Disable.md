475
  "WPFTweaksTelemetry": {
476
    "Content": "Telemetry - Disable",
477
    "Description": "Disables Microsoft Telemetry.",
478
    "category": "Essential Tweaks",
479
    "panel": "1",
480
    "registry": [
481
      {
482
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo",
483
        "Name": "Enabled",
484
        "Value": "0",
485
        "Type": "DWord",
486
        "OriginalValue": "<RemoveEntry>"
487
      },
488
      {
489
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Privacy",
490
        "Name": "TailoredExperiencesWithDiagnosticDataEnabled",
491
        "Value": "0",
492
        "Type": "DWord",
493
        "OriginalValue": "<RemoveEntry>"
494
      },
495
      {
496
        "Path": "HKCU:\\Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy",
497
        "Name": "HasAccepted",
498
        "Value": "0",
499
        "Type": "DWord",
500
        "OriginalValue": "<RemoveEntry>"
501
      },
502
      {
503
        "Path": "HKCU:\\Software\\Microsoft\\Input\\TIPC",
504
        "Name": "Enabled",
505
        "Value": "0",
506
        "Type": "DWord",
507
        "OriginalValue": "<RemoveEntry>"
508
      },
509
      {
510
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization",
511
        "Name": "RestrictImplicitInkCollection",
512
        "Value": "1",
513
        "Type": "DWord",
514
        "OriginalValue": "<RemoveEntry>"
515
      },
516
      {
517
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization",
518
        "Name": "RestrictImplicitTextCollection",
519
        "Value": "1",
520
        "Type": "DWord",
521
        "OriginalValue": "<RemoveEntry>"
522
      },
523
      {
524
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization\\TrainedDataStore",
525
        "Name": "HarvestContacts",
526
        "Value": "0",
527
        "Type": "DWord",
528
        "OriginalValue": "<RemoveEntry>"
529
      },
530
      {
531
        "Path": "HKCU:\\Software\\Microsoft\\Personalization\\Settings",
532
        "Name": "AcceptedPrivacyPolicy",
533
        "Value": "0",
534
        "Type": "DWord",
535
        "OriginalValue": "<RemoveEntry>"
536
      },
537
      {
538
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\DataCollection",
539
        "Name": "AllowTelemetry",
540
        "Value": "0",
541
        "Type": "DWord",
542
        "OriginalValue": "<RemoveEntry>"
543
      },
544
      {
545
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
546
        "Name": "Start_TrackProgs",
547
        "Value": "0",
548
        "Type": "DWord",
549
        "OriginalValue": "<RemoveEntry>"
550
      },
551
      {
552
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
553
        "Name": "PublishUserActivities",
554
        "Value": "0",
555
        "Type": "DWord",
556
        "OriginalValue": "<RemoveEntry>"
557
      },
558
      {
559
        "Path": "HKCU:\\Software\\Microsoft\\Siuf\\Rules",
560
        "Name": "NumberOfSIUFInPeriod",
561
        "Value": "0",
562
        "Type": "DWord",
563
        "OriginalValue": "<RemoveEntry>"
564
      }
565
    ],
566
    "InvokeScript": [
567
      "
568
      # Disable Defender Auto Sample Submission
569
      Set-MpPreference -SubmitSamplesConsent 2
570

571
      # Disable (Connected User Experiences and Telemetry) Service
572
      Set-Service -Name diagtrack -StartupType Disabled
573

574
      # Disable (Windows Error Reporting Manager) Service
575
      Set-Service -Name wermgr -StartupType Disabled
576

577
      Remove-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds
578
      "
579
    ],
580
    "UndoScript": [
581
      "
582
      # Enable Defender Auto Sample Submission
583
      Set-MpPreference -SubmitSamplesConsent 1
584

585
      # Enable (Connected User Experiences and Telemetry) Service
586
      Set-Service -Name diagtrack -StartupType Automatic
587

588
      # Enable (Windows Error Reporting Manager) Service
589
      Set-Service -Name wermgr -StartupType Automatic
590
      "
591
    ],