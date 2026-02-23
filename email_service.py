"""
Fetch HDFC UPI transaction emails via IMAP and parse amount + date.
"""
import imaplib
import email
import re
import os
from email.header import decode_header
from datetime import datetime


def get_imap_connection():
    """Connect to IMAP server using env vars."""
    host = os.getenv("IMAP_HOST", "imap.gmail.com")
    port = int(os.getenv("IMAP_PORT", "993"))
    user = os.getenv("IMAP_USER", "")
    password = os.getenv("IMAP_PASSWORD", "")
    if not user or not password:
        raise ValueError("Set IMAP_USER and IMAP_PASSWORD in .env")
    conn = imaplib.IMAP4_SSL(host, port=port)
    conn.login(user, password)
    return conn


def decode_mime_header(header):
    """Decode MIME encoded header (e.g. subject)."""
    if header is None:
        return ""
    decoded_parts = []
    for part, charset in decode_header(header):
        if isinstance(part, bytes):
            decoded_parts.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded_parts.append(part or "")
    return " ".join(decoded_parts)


def _strip_html(html):
    """Remove HTML tags and decode entities for plain text."""
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def get_body(msg):
    """Extract plain text body from email; fallback to HTML (stripped) if no plain part."""
    plain = ""
    html = ""
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            try:
                raw = part.get_payload(decode=True)
                if raw is None:
                    raw = part.get_payload() or b""
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8", errors="replace")
                else:
                    raw = str(raw)
            except Exception:
                raw = str(part.get_payload() or "")
            if ctype == "text/plain":
                plain = raw
                break
            elif ctype == "text/html" and not html:
                html = raw
    else:
        try:
            raw = msg.get_payload(decode=True)
            if raw is None:
                raw = msg.get_payload() or b""
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8", errors="replace")
            plain = raw
        except Exception:
            plain = str(msg.get_payload() or "")
    body = plain.strip() if plain else _strip_html(html) if html else ""
    return body


# HDFC / UPI: "Rs.420.00 has been debited" or "Rs 100" or "debited ... Rs. 50" etc.
AMOUNT_PATTERNS = [
    re.compile(r"[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)\s+has\s+been\s+debited", re.IGNORECASE),
    re.compile(r"debited?\s*(?:by|of)?\s*[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)", re.IGNORECASE),
    re.compile(r"[Rr]s\.?\s*([\d,]+(?:\.\d{2})?)", re.IGNORECASE),
    re.compile(r"INR\s*([\d,]+(?:\.\d{2})?)", re.IGNORECASE),
    re.compile(r"₹\s*([\d,]+(?:\.\d{2})?)"),
    re.compile(r"amount\s*[:\s]*([\d,]+(?:\.\d{2})?)", re.IGNORECASE),
]


def parse_amount(text):
    """Extract numeric amount from email text. Returns float or None."""
    for pat in AMOUNT_PATTERNS:
        m = pat.search(text)
        if m:
            raw = m.group(1) if m.lastindex else m.group(0)
            # Keep only digits and one decimal point
            raw = re.sub(r"[^\d.]", "", raw.replace(",", ""))
            try:
                return round(float(raw), 2)
            except ValueError:
                continue
    return None


def parse_date_from_body(text):
    """Try to find a date in email body. HDFC uses DD-MM-YY (e.g. 22-02-26)."""
    # DD-MM-YY or DD/MM/YY (2-digit year)
    m = re.search(r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b", text)
    if m:
        try:
            d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
            if y < 100:
                y += 2000
            if 1 <= d <= 31 and 1 <= mo <= 12:
                return datetime(y, mo, d).date()
        except (ValueError, TypeError):
            pass
    # DD Month YYYY
    m = re.search(r"\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{2,4})\b", text, re.I)
    if m:
        try:
            from datetime import datetime as dt
            return dt.strptime(f"{m.group(1)} {m.group(2)[:3]} {m.group(3)}", "%d %b %Y").date()
        except (ValueError, TypeError):
            pass
    return None


def extract_snippet(body):
    """Extract a short description from HDFC UPI body (e.g. 'to VPA ... MERCHANT NAME')."""
    # "debited from account 8159 to VPA q937925259@ybl HYGROW POULTRY EQUIP on 22-02-26"
    m = re.search(r"to\s+VPA\s+([^.]+?)(?:\s+on\s+\d{1,2}-\d{1,2}-\d{2,4}|\s*\.|$)", body, re.IGNORECASE | re.DOTALL)
    if m:
        return m.group(1).strip().replace("\n", " ")[:200]
    return body.replace("\n", " ").strip()[:200]


def parse_email_date(msg):
    """Get date from email Date header."""
    date_str = msg.get("Date")
    if not date_str:
        return None
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(date_str).date()
    except Exception:
        return None


def is_upi_related(subject, body):
    """Heuristic: email is about UPI transaction."""
    combined = (subject + " " + body).lower()
    return "upi" in combined or "debited" in combined or "payment" in combined


def fetch_last_upi_transactions(max_count=10, from_filter=None):
    """
    Fetch last N UPI-related emails, parse amount and date.
    Returns list of dicts: { email_id, subject, date, amount, snippet, body }.
    """
    conn = get_imap_connection()
    try:
        conn.select("INBOX")
        # Search: all mail, or from specific sender
        if from_filter:
            _, data = conn.search(None, f'(FROM "{from_filter}")')
        else:
            _, data = conn.search(None, "ALL")
        msg_ids = data[0].split()
        msg_ids.reverse()  # newest first
        results = []
        for mid in msg_ids:
            if len(results) >= max_count:
                break
            try:
                _, msg_data = conn.fetch(mid, "(RFC822)")
                for part in msg_data:
                    if isinstance(part, tuple):
                        msg = email.message_from_bytes(part[1])
                    else:
                        continue
                subject = decode_mime_header(msg.get("Subject"))
                body = get_body(msg)
                if not is_upi_related(subject, body):
                    continue
                text_for_parse = subject + " " + body
                amount = parse_amount(text_for_parse)
                date = parse_date_from_body(body) or parse_email_date(msg)
                if not date:
                    date = parse_email_date(msg)
                snippet = extract_snippet(body) if body else (subject[:200] if subject else "")
                results.append({
                    "email_id": mid.decode() if isinstance(mid, bytes) else str(mid),
                    "subject": subject[:120],
                    "date": date.isoformat() if date else None,
                    "amount": amount,
                    "snippet": snippet or (body or subject)[:200].replace("\n", " ").strip(),
                    "body": body or "",
                })
            except Exception:
                continue
        return results
    finally:
        try:
            conn.logout()
        except Exception:
            pass
