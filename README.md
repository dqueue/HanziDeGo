# Hanzi De Go

A browser MVP for a simplified Chinese 成语 missing-character sprint.

Open `public/index.html` in a browser to play. The canonical question source is `public/chengyu_frequency.json`; `public/chengyu_frequency.js` exposes the same payload for direct browser loading.

The generated data comes from:

- `THUOCL_chengyu.txt`: 清华大学开放中文词库成语词表, using the DF frequency value.
- `idiom.json`: Chinese idiom metadata. Entries absent from THUOCL are included in the hardest band.

Run `scripts/build_chengyu_data.mjs` to regenerate `public/chengyu_frequency.json` and `public/chengyu_frequency.js`.

Current generated source:

- 31,856 total entries
- 常见: 2,130
- 核心: 2,982
- 冷门: 3,407
- 最难: 23,337 dictionary-only entries

Current MVP:

- 成语 prompts from the merged source list
- One random character blanked per question
- Chinese-character answer checking
- Any source 成语 matching the visible pattern is accepted
- All accepted possibilities are shown after each resolved question
- Chinese definitions are shown after submitted guesses and resolved questions
- Per-question timer
- Multiple guesses per question
- Lives are lost only on skip or timeout
- Frequency/dictionary bands: 常见, 核心, 冷门, 最难
- Lives, streaks, scoring, and best score in local storage
