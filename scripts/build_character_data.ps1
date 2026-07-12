$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "characters.csv"
$supportedPath = Join-Path $root "public\vendor\paddleocr\supported_characters.txt"
$outputPath = Join-Path $root "public\character_data.js"

$supportedText = [System.IO.File]::ReadAllText($supportedPath, [System.Text.Encoding]::UTF8)
$supported = [System.Collections.Generic.HashSet[string]]::new()
foreach ($character in $supportedText.ToCharArray()) {
  [void]$supported.Add([string]$character)
}

$rows = Import-Csv -LiteralPath $csvPath -Encoding utf8
$seen = [System.Collections.Generic.HashSet[string]]::new()
$rejected = [System.Collections.Generic.List[string]]::new()
$entries = [System.Collections.Generic.List[object]]::new()
$levelCutoffs = @(100, 300, 600, 1000, 2000)

for ($rowIndex = 0; $rowIndex -lt $rows.Count; $rowIndex += 1) {
  $row = $rows[$rowIndex]
  $hanzi = $row.hanzi_sc.Trim()
  if ($hanzi.Length -ne 1 -or -not $supported.Contains($hanzi) -or -not $seen.Add($hanzi)) {
    $rejected.Add($hanzi)
    continue
  }

  $rank = $entries.Count + 1
  $level = 6
  for ($cutoffIndex = 0; $cutoffIndex -lt $levelCutoffs.Count; $cutoffIndex += 1) {
    if ($rank -le $levelCutoffs[$cutoffIndex]) {
      $level = $cutoffIndex + 1
      break
    }
  }
  $entries.Add([ordered]@{
    hanzi = $hanzi
    traditional = $row.hanzi_trad.Trim()
    pinyin = $row.pinyin.Trim()
    pinyinNumbered = $row.pinyin_style2.Trim()
    rank = $rank
    level = $level
    levelLabel = "Level $level"
    definition = $row.cc_cedict_definitions.Trim()
  })
}

$payload = [ordered]@{
  meta = [ordered]@{
    sourceRows = $rows.Count
    playableRows = $entries.Count
    rejectedRows = $rejected.Count
    recognizerVocabulary = $supported.Count
    recognizer = "PaddleOCR.js PP-OCRv5 mobile recognition"
    levelCutoffs = $levelCutoffs
  }
  entries = $entries
}

$json = $payload | ConvertTo-Json -Depth 5 -Compress
[System.IO.File]::WriteAllText(
  $outputPath,
  "window.CHARACTER_DATA = $json;`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Built $($entries.Count) playable characters; filtered $($rejected.Count); recognizer vocabulary $($supported.Count)."
