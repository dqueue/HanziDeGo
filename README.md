# Hanzi De Go

A browser-based simplified Chinese character writing sprint.

The game gives a pinyin and a concise Chinese definition from `word.json`. Round-parenthetical content is removed, clues are capped at 100 characters with `...`, and every occurrence of the answer glyph or its listed traditional form is shown as `~` until resolution. Draw the matching character on the canvas, then press **Check writing**. The completed ink is normalized into an image and recognized by PP-OCRv5; stroke order and stroke direction are not passed to the model.

Undo, redo, clear, OCR candidates, six frequency levels, three campaign modes, lives, streaks, scoring, 60-second questions, and local best scores are included. The five most recent results retain small in-memory thumbnails of the player's writing; they are never uploaded or persisted.

## Run locally

Serve the `public` directory over HTTP so the model and WebAssembly runtime can load:

```powershell
python -m http.server 8000 --directory public
```

Then open `http://localhost:8000`.

The 16 MB recognition model is stored locally in `public/vendor/paddleocr`. ONNX Runtime Web is loaded from jsDelivr.

## Character data

`characters.csv` is the source. Regenerate `public/character_data.js` with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_character_data.ps1
```

The build intersects the CSV with `public/vendor/paddleocr/supported_characters.txt`, derived from PaddleOCR's official PP-OCRv5 dictionary. Characters absent from the model are excluded automatically.

Current generated source:

- 2,791 source rows in `characters.csv`
- 2,789 ranked characters with Chinese dictionary definitions
- 2 excluded because `word.json` has no matching single-character entry
- Level 1 (ranks 1–100): 100
- Level 2 (ranks 101–300): 200
- Level 3 (ranks 301–600): 300
- Level 4 (ranks 601–1,000): 400
- Level 5 (ranks 1,001–2,000): 1,000
- Level 6 (ranks 2,001+): 789
- Level 7: 11,059 unique characters in both `word.json` and the OCR vocabulary

## Campaign modes

Every campaign contains 16 questions: five questions from each of its first three levels, followed by one final-boss question from the fourth level.

Only correct answers advance the campaign. A miss, timeout, or skip costs a life and replaces the prompt with a different character from the same level without moving the stage or route marker.

- Normal: levels 1, 2, 3, then a level 4 boss
- Hard: levels 2, 3, 4, then a level 5 boss
- Very hard: levels 3, 4, 5, then a level 6 boss
- Extreme: levels 4, 5, 6, then a level 7 dictionary boss

Constant practice modes are also available for each individual level from 1 through 7; all 16 questions stay in the selected level.

## Handwriting recognition

The game uses the official PP-OCRv5 mobile recognition model from [`PaddlePaddle/PaddleOCR`](https://github.com/PaddlePaddle/PaddleOCR). Its dictionary contains 15,700 unique Han characters, covering all 11,059 Level 7 dictionary characters.

Only the recognition network is used. The document text-region detector is intentionally bypassed because it can reject sparse isolated characters such as 十. The final drawing is cropped, centered, resized to the model's `3 × 48 × 320` input, and evaluated locally in the browser with ONNX Runtime Web.

The CTC output is constrained to exactly one playable Han character across the complete image. The row beneath the canvas contains ranked alternative single-character hypotheses, not a multi-character transcription. This prevents the decoder itself from splitting a left and right component into separate output characters, although a component-shaped character can still be an incorrect alternative from the underlying text-recognition model.

Third-party notices and the Apache 2.0 license are in `public/vendor/paddleocr`.
