$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "characters.csv"
$supportedPath = Join-Path $root "public\vendor\hanzi_lookup\supported_characters.txt"
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

foreach ($row in $rows) {
  $hanzi = $row.hanzi_sc.Trim()
  if ($hanzi.Length -ne 1 -or -not $supported.Contains($hanzi) -or -not $seen.Add($hanzi)) {
    $rejected.Add($hanzi)
    continue
  }

  $level = [int]$row.level
  $band = if ($level -le 3) { "beginner" } elseif ($level -le 6) { "intermediate" } else { "advanced" }
  $entries.Add([ordered]@{
    hanzi = $hanzi
    traditional = $row.hanzi_trad.Trim()
    pinyin = $row.pinyin.Trim()
    pinyinNumbered = $row.pinyin_style2.Trim()
    level = $level
    levelLabel = $row.level_zh.Trim()
    definition = $row.cc_cedict_definitions.Trim()
    band = $band
  })
}

$payload = [ordered]@{
  meta = [ordered]@{
    sourceRows = $rows.Count
    playableRows = $entries.Count
    rejectedRows = $rejected.Count
    recognizerVocabulary = $supported.Count
    recognizer = "gugray/hanzi_lookup (Make Me a Hanzi model)"
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
