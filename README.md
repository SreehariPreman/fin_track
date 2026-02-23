# Fin Track

A simple finance tracking app that reads **HDFC UPI transaction emails** from your mailbox, extracts amount and date, and lets you categorise transactions for money management.

## Features

- **Fetch UPI emails**: Pull last 10 UPI-related emails from your inbox (IMAP).
- **View transactions**: See date, amount, and a short snippet for each.
- **Categorise**: Assign each transaction to a category (dropdown + Save).
- **Create categories**: Add new categories (e.g. Food, Transport, Bills).

## How to access mail from code (IMAP)

The app uses **IMAP** (Internet Message Access Protocol) to read emails:

1. **IMAP** lets a client read and search mail on the server without deleting it. Your mail stays in Gmail; we only read it.
2. **Gmail setup**:
   - In Gmail: **Settings → See all settings → Forwarding and POP/IMAP** → enable **IMAP access**.
   - If you use **2-Step Verification**: go to [Google Account → Security → App passwords](https://myaccount.google.com/apppasswords), create an app password for “Mail”, and use that in `.env` as `IMAP_PASSWORD` (not your normal Gmail password).
3. **Other providers**: Use their IMAP host (e.g. Outlook: `outlook.office365.com`, port 993). Same idea: enable IMAP and use app password if required.

The code lives in `email_service.py`: it connects with `imaplib.IMAP4_SSL`, selects `INBOX`, searches emails (optionally by sender), and parses each message’s body to find amount and date.

## Setup

1. **Clone and install**
   ```bash
   cd fin_track
   python3 -m venv .venv
   source .venv/bin/activate   # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Configure mail**
   ```bash
   cp .env.example .env
   # Edit .env and set:
   # IMAP_USER=your.email@gmail.com
   # IMAP_PASSWORD=your_app_password
   # Optional: IMAP_FROM_FILTER=hdfcbank   to only search emails from HDFC
   ```

3. **Run**
   ```bash
   python app.py
   ```
   Open http://127.0.0.1:5000

## Usage

1. Click **“Fetch last 10 UPI emails”** to load recent UPI-related emails into the app (new ones are stored in SQLite).
2. In the table, pick a **Category** from the dropdown for each transaction and click **Save**.
3. Use **“Create category”** to add new categories (e.g. Groceries, Rent), then assign them to transactions.

Data is stored in `fin_track.db` (SQLite) in the project folder.

## HDFC emails

The parser looks for UPI-related wording (e.g. “UPI”, “debited”, “payment”) and extracts amount (e.g. Rs. 500, ₹500, INR 500) and date from the body or email header. If your HDFC alert format differs, you can adjust the patterns in `email_service.py` (`AMOUNT_PATTERNS`, `parse_date_from_body`, `is_upi_related`).

## Tech

- **Backend**: Flask, SQLite
- **Mail**: Python `imaplib` + `email`
- **UI**: Simple server-rendered HTML/CSS
