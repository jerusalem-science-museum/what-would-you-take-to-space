# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"What Would You Take to Space?" — an interactive touchscreen kiosk exhibit for a science museum. Visitors select up to 3 items they'd bring to space; their votes accumulate into a word cloud shown to all visitors.

**Deployment target:** Linux (Raspberry Pi/similar), Chromium in kiosk mode, portrait 9:16 touchscreen display.

## Running the App

**Development (Windows):**
```bash
venv.bat          # activates .venv
flask run         # starts on http://localhost:5000
```

**Production (Linux kiosk):**
```bash
./run_app.sh      # launches Flask + Chromium in kiosk mode
./fix_touch.sh    # if touchscreen maps to wrong display
```

No build step — Flask serves templates and static files directly.

## Architecture

Single-server kiosk app. No database; vote counts persist in `votes.json`. Wordclouds are PNG files generated server-side and served as static assets.

**Backend (`app.py`):** Single Flask file. Key routes:
- `POST /submit-vote` — appends 3 selected items to `votes.json`
- `POST /preview-wordcloud` — generates wordcloud PNGs for all 3 languages using a hypothetical vote (without committing); saves as `preview_wordcloud_<lang>.png`
- `POST /commit-wordcloud` — copies preview PNGs to final `wordcloud_<lang>.png`
- `POST /regenerate-wordcloud` — rebuilds wordclouds from current `votes.json`
- `GET/POST /font-sizes` — reads/writes `fontsizes.json` for per-language font size tuning

Wordcloud generation: 1200×1200 RGBA PNGs, language-specific fonts (EzerEuro for EN/HE, Cairo/NotoSansArabic for AR), fixed brand color palette.

**Frontend (`static/js/app.js`):** Vanilla JS, no frameworks.
- Single-page experience: `.selection-container` and `.wordcloud-container` toggled via `is-hidden` CSS class
- `loadTranslations(lang)` fetches `/translations/<lang>.json` and caches in memory; swaps all `data-key` attributed elements
- Language switching sets `dir="rtl"` on `<html>` for Hebrew/Arabic; applies `lang-he`/`lang-ar` CSS classes for font overrides
- Launch flow: `precomputeWordcloud()` and `playRocketLaunchAnimation()` run in parallel, then vote is submitted, wordcloud committed, and wordcloud view shown
- 20-second auto-return timer after wordcloud is displayed (`AUTO_RETURN_DELAY_MS = 20000`)

**Templates (`templates/`):** `index.html` is the main SPA; `wordcloud.html` is a standalone fallback for direct `/wordcloud` navigation.

**Translations (`translations/`):** `en.json`, `he.json`, `ar.json` — 12 item names + UI strings, keyed consistently.

**Data files:**
- `votes.json` — live vote counts for items 1–12 plus `totalvotes`
- `fontsizes.json` — per-language font size overrides, keyed as `"<lang>:<item_name>": <size>`

## Key Constraints

- Touch events only (no hover states needed); text selection, drag, and pinch-to-zoom are disabled
- Fixed portrait aspect ratio — layout is letterboxed in CSS, not responsive
- RTL languages (Hebrew, Arabic) must work without page reload
- The preview/commit two-step for wordcloud generation prevents displaying a corrupted image if the vote submission fails mid-flight
