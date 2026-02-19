# What Would You Take to Space?

An interactive touchscreen kiosk exhibit for a science museum. Visitors pick up to 3 items they'd bring to space; their choices accumulate into a live word cloud visible to all visitors.

**Languages:** English, Hebrew (RTL), Arabic (RTL)
**Deployment:** Portrait 9:16 touchscreen, Chromium kiosk mode, Linux (mint or similar)

## Setup

> **Linux Mint assumed** for production deployment. The setup script and autostart integration target the Cinnamon/MATE desktop environment (`~/.config/autostart`).

**One-time setup (Linux Mint):**
```bash
bash setup.sh
```

This installs Python dependencies into `.venv`, updates the project path in `run_app.sh` to match the current machine, makes scripts executable, and registers both `run_app.sh` and `fix_touch.sh` to run automatically on login.

**Manual setup (Windows / other):**
```bash
python -m venv .venv
source .venv/bin/activate   # Linux/macOS
# or: venv.bat              # Windows
pip install -r requirements.txt
```

## Running

**Development:**
```bash
flask run
# Open http://localhost:5000
```

**Production (kiosk):**
```bash
./run_app.sh      # starts Flask + opens Chromium in kiosk mode
./fix_touch.sh    # maps touchscreen to the correct display (see comments in the file)
```
After running `setup.sh`, both scripts launch automatically on login.

## How It Works

1. Visitor selects up to 3 items from a grid of 12, which appear in the rocket's cargo slots.
2. Tapping "Launch!" animates the rocket while pre-generating the word cloud in the background.
3. The word cloud view displays (in the visitor's chosen language) showing how everyone has voted.
4. After 20 seconds the screen resets automatically for the next visitor.

## Data

- `votes.json` — running vote totals; edit or reset this file to clear/adjust counts.
- `fontsizes.json` — per-language font size overrides for the word cloud, keyed as `"<lang>:<item_name>": <size>`.

To force-regenerate the word cloud images from current vote data:

```bash
curl -X POST http://localhost:5000/regenerate-wordcloud
```

## Adding / Editing Items

Items and UI strings live in `translations/en.json`, `translations/he.json`, and `translations/ar.json`. Each file has 12 item keys (`item1`–`item12`) plus UI copy. Keep all three files in sync when editing.
