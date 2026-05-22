1840
  "WPFTweaksDisableExplorerAutoDiscovery": {
1841
    "Content": "File Explorer Automatic Folder Discovery - Disable",
1842
    "Description": "Windows Explorer automatically tries to guess the type of the folder based on its contents, slowing down the browsing experience. WARNING! Will disable File Explorer grouping.",
1843
    "category": "Essential Tweaks",
1844
    "panel": "1",
1845
    "InvokeScript": [
1846
      "
1847
      # Previously detected folders
1848
      $bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"
1849

1850
      # Folder types lookup table
1851
      $bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"
1852

1853
      # Flush Explorer view database
1854
      Remove-Item -Path $bags -Recurse -Force
1855
      Write-Host \"Removed $bags\"
1856

1857
      Remove-Item -Path $bagMRU -Recurse -Force
1858
      Write-Host \"Removed $bagMRU\"
1859

1860
      # Every folder
1861
      $allFolders = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\\AllFolders\\Shell\"
1862

1863
      if (!(Test-Path $allFolders)) {
1864
        New-Item -Path $allFolders -Force
1865
        Write-Host \"Created $allFolders\"
1866
      }
1867

1868
      # Generic view
1869
      New-ItemProperty -Path $allFolders -Name \"FolderType\" -Value \"NotSpecified\" -PropertyType String -Force
1870
      Write-Host \"Set FolderType to NotSpecified\"
1871

1872
      Write-Host Please sign out and back in, or restart your computer to apply the changes!
1873
      "
1874
    ],
1875
    "UndoScript": [
1876
      "
1877
      # Previously detected folders
1878
      $bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"
1879

1880
      # Folder types lookup table
1881
      $bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"
1882

1883
      # Flush Explorer view database
1884
      Remove-Item -Path $bags -Recurse -Force
1885
      Write-Host \"Removed $bags\"
1886

1887
      Remove-Item -Path $bagMRU -Recurse -Force
1888
      Write-Host \"Removed $bagMRU\"
1889

1890
      Write-Host Please sign out and back in, or restart your computer to apply the changes!
1891
      "
1892
    ],