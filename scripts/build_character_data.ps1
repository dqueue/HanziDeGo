$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "characters.csv"
$dictionaryPath = Join-Path $root "word.json"
$supportedPath = Join-Path $root "public\vendor\paddleocr\supported_characters.txt"
$outputPath = Join-Path $root "public\character_data.js"

function Normalize-Pinyin([string]$value) {
  if ($null -eq $value) { return "" }
  return (($value.ToLowerInvariant() -replace [string][char]0x0261, "g") -replace "\s+", "")
}

function Get-ConciseDefinition([string]$value) {
  $clean = $value
  $numberedStart = [regex]::Match($clean, "\u2488|^1\.|(?<=\s)1\.", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($numberedStart.Success) { $clean = $clean.Substring($numberedStart.Index) }
  do {
    $previous = $clean
    $clean = ($clean -replace "\([^()]*\)", " ") -replace "\uFF08[^\uFF08\uFF09]*\uFF09", " "
  } while ($clean -ne $previous)
  $clean = (($clean -replace "[()]", " ") -replace "\uFF08|\uFF09", " ")
  $clean = ($clean -replace "\s+", " ").Trim()
  if ($clean.Length -le 50) { return $clean }
  return $clean.Substring(0, 47).TrimEnd() + "..."
}

$supportedText = [System.IO.File]::ReadAllText($supportedPath, [System.Text.Encoding]::UTF8)
$supported = [System.Collections.Generic.HashSet[string]]::new()
foreach ($character in $supportedText.ToCharArray()) { [void]$supported.Add([string]$character) }

$dictionaryRows = Get-Content -Raw -Encoding utf8 $dictionaryPath | ConvertFrom-Json
$dictionaryByCharacter = @{}
foreach ($dictionaryRow in $dictionaryRows) {
  $word = [string]$dictionaryRow.word
  if ($word.Length -ne 1 -or -not $supported.Contains($word) -or [string]::IsNullOrWhiteSpace($dictionaryRow.explanation)) { continue }
  if (-not $dictionaryByCharacter.ContainsKey($word)) {
    $dictionaryByCharacter[$word] = [System.Collections.Generic.List[object]]::new()
  }
  $dictionaryByCharacter[$word].Add($dictionaryRow)
}

function Select-DictionaryEntry([string]$character, [string]$preferredPinyin = "") {
  if (-not $dictionaryByCharacter.ContainsKey($character)) { return $null }
  $candidates = @($dictionaryByCharacter[$character])
  $normalizedPreferred = Normalize-Pinyin $preferredPinyin
  if ($normalizedPreferred) {
    $matching = @($candidates | Where-Object { (Normalize-Pinyin ([string]$_.pinyin)) -eq $normalizedPreferred })
    if ($matching.Count -gt 0) { $candidates = $matching }
  }
  return $candidates | Sort-Object @{ Expression = { ([string]$_.explanation).Length }; Descending = $true } | Select-Object -First 1
}

$rows = @(Import-Csv -LiteralPath $csvPath -Encoding utf8)
$seen = [System.Collections.Generic.HashSet[string]]::new()
$ocrRejected = [System.Collections.Generic.List[string]]::new()
$dictionaryRejected = [System.Collections.Generic.List[string]]::new()
$entries = [System.Collections.Generic.List[object]]::new()
$levelCutoffs = @(100, 300, 600, 1000, 2000)

foreach ($row in $rows) {
  $hanzi = $row.hanzi_sc.Trim()
  if ($hanzi.Length -ne 1 -or -not $supported.Contains($hanzi) -or -not $seen.Add($hanzi)) {
    $ocrRejected.Add($hanzi)
    continue
  }
  $dictionaryEntry = Select-DictionaryEntry $hanzi $row.pinyin.Trim()
  if ($null -eq $dictionaryEntry) {
    $dictionaryRejected.Add($hanzi)
    continue
  }

  $rank = $entries.Count + 1
  $level = 6
  for ($cutoffIndex = 0; $cutoffIndex -lt $levelCutoffs.Count; $cutoffIndex += 1) {
    if ($rank -le $levelCutoffs[$cutoffIndex]) { $level = $cutoffIndex + 1; break }
  }
  $entries.Add([ordered]@{
    hanzi = $hanzi
    traditional = $row.hanzi_trad.Trim()
    pinyin = $row.pinyin.Trim()
    pinyinNumbered = $row.pinyin_style2.Trim()
    rank = $rank
    level = $level
    levelLabel = "Level $level"
    definition = Get-ConciseDefinition ([string]$dictionaryEntry.explanation)
  })
}

$level7Entries = [System.Collections.Generic.List[object]]::new()
$level7Seen = [System.Collections.Generic.HashSet[string]]::new()
foreach ($dictionaryRow in $dictionaryRows) {
  $hanzi = [string]$dictionaryRow.word
  if (-not $dictionaryByCharacter.ContainsKey($hanzi) -or -not $level7Seen.Add($hanzi)) { continue }
  $selected = Select-DictionaryEntry $hanzi ([string]$dictionaryRow.pinyin)
  $traditional = ([string]$selected.oldword).Trim()
  if (-not $traditional) { $traditional = $hanzi }
  $pinyin = ([string]$selected.pinyin).Trim()
  if (-not $pinyin) { $pinyin = "-" }
  $level7Entries.Add([ordered]@{
    hanzi = $hanzi
    traditional = $traditional
    pinyin = $pinyin
    pinyinNumbered = ""
    rank = $null
    level = 7
    levelLabel = "Level 7"
    definition = Get-ConciseDefinition ([string]$selected.explanation)
  })
}

$payload = [ordered]@{
  meta = [ordered]@{
    sourceRows = $rows.Count
    rankedPlayableRows = $entries.Count
    playableRows = $level7Entries.Count
    rejectedRows = $ocrRejected.Count + $dictionaryRejected.Count
    ocrRejectedRows = $ocrRejected.Count
    dictionaryRejectedRows = $dictionaryRejected.Count
    recognizerVocabulary = $supported.Count
    recognizer = "PaddleOCR.js PP-OCRv5 mobile recognition"
    dictionary = "word.json"
    levelCutoffs = $levelCutoffs
  }
  entries = $entries
  level7Entries = $level7Entries
}

$json = $payload | ConvertTo-Json -Depth 5 -Compress
[System.IO.File]::WriteAllText(
  $outputPath,
  "window.CHARACTER_DATA = $json;`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Built $($entries.Count) ranked characters and $($level7Entries.Count) Level 7 dictionary characters; filtered $($ocrRejected.Count) for OCR and $($dictionaryRejected.Count) for dictionary coverage."