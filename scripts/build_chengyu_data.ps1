$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$chengyuPath = Join-Path $root "chengyu.txt"
$dictionaryPath = Join-Path $root "word.json"
$supportedPath = Join-Path $root "public\vendor\paddleocr\supported_characters.txt"
$outputPath = Join-Path $root "public\chengyu_data.js"
$box = [string][char]0x25A1

$supportedText = [System.IO.File]::ReadAllText($supportedPath, [System.Text.Encoding]::UTF8)
$supported = [System.Collections.Generic.HashSet[string]]::new()
foreach ($character in $supportedText.ToCharArray()) { [void]$supported.Add([string]$character) }

$dictionaryRows = Get-Content -Raw -Encoding utf8 $dictionaryPath | ConvertFrom-Json
$dictionaryByCharacter = @{}
foreach ($row in $dictionaryRows) {
  $character = [string]$row.word
  if ($character.Length -ne 1 -or $dictionaryByCharacter.ContainsKey($character)) { continue }
  $dictionaryByCharacter[$character] = $row
}

$expressions = [System.Collections.Generic.List[string]]::new()
$seenExpressions = [System.Collections.Generic.HashSet[string]]::new()
foreach ($line in Get-Content -LiteralPath $chengyuPath -Encoding utf8) {
  $expression = $line.Trim()
  if (-not $expression -or $expression.StartsWith("#") -or -not $seenExpressions.Add($expression)) { continue }
  $expressions.Add($expression)
}

$candidatesByCharacter = @{}
$sourceCharacters = [System.Collections.Generic.HashSet[string]]::new()
$ocrRejected = [System.Collections.Generic.HashSet[string]]::new()
$dictionaryRejected = [System.Collections.Generic.HashSet[string]]::new()

foreach ($expression in $expressions) {
  $seenInExpression = [System.Collections.Generic.HashSet[string]]::new()
  foreach ($value in $expression.ToCharArray()) {
    $character = [string]$value
    if (-not $seenInExpression.Add($character)) { continue }
    [void]$sourceCharacters.Add($character)
    if (-not $supported.Contains($character)) { [void]$ocrRejected.Add($character); continue }
    if (-not $dictionaryByCharacter.ContainsKey($character)) { [void]$dictionaryRejected.Add($character); continue }
    if (-not $candidatesByCharacter.ContainsKey($character)) {
      $candidatesByCharacter[$character] = [System.Collections.Generic.List[string]]::new()
    }
    $candidatesByCharacter[$character].Add($expression)
  }
}

$random = [System.Random]::new(20260713)
$entries = [System.Collections.Generic.List[object]]::new()
foreach ($character in @($candidatesByCharacter.Keys | Sort-Object)) {
  $candidates = @($candidatesByCharacter[$character])
  $fourCharacterCandidates = @($candidates | Where-Object { $_.Length -eq 4 })
  $preferred = if ($fourCharacterCandidates.Count -gt 0) { $fourCharacterCandidates } else { $candidates }
  $preferred = @($preferred)
  $expression = $preferred[$random.Next($preferred.Count)]
  $dictionaryEntry = $dictionaryByCharacter[$character]
  $pinyin = ([string]$dictionaryEntry.pinyin).Trim()
  if (-not $pinyin) { $pinyin = "-" }
  $traditional = ([string]$dictionaryEntry.oldword).Trim()
  if (-not $traditional) { $traditional = $character }

  $entries.Add([ordered]@{
    hanzi = $character
    traditional = $traditional
    pinyin = $pinyin
    pinyinNumbered = ""
    rank = $null
    level = 0
    levelLabel = "Chengyu"
    definition = $expression
    clue = $expression.Replace($character, $box)
  })
}

$payload = [ordered]@{
  meta = [ordered]@{
    sourceExpressions = $expressions.Count
    fourCharacterExpressions = @($expressions | Where-Object { $_.Length -eq 4 }).Count
    uniqueSourceCharacters = $sourceCharacters.Count
    playableCharacters = $entries.Count
    rejectedCharacters = $ocrRejected.Count + $dictionaryRejected.Count
    ocrRejectedCharacters = $ocrRejected.Count
    dictionaryRejectedCharacters = $dictionaryRejected.Count
    selectionSeed = 20260713
    source = "chengyu.txt"
    dictionary = "word.json"
  }
  entries = $entries
}

$json = $payload | ConvertTo-Json -Depth 5 -Compress
[System.IO.File]::WriteAllText(
  $outputPath,
  "window.CHENGYU_DATA = $json;`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Built $($entries.Count) unique Chengyu characters from $($expressions.Count) expressions; filtered $($ocrRejected.Count) for OCR and $($dictionaryRejected.Count) for dictionary coverage."
