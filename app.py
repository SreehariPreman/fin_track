"""
Fin Track - Simple finance tracking from HDFC UPI email alerts.
"""
import os
import sqlite3
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, flash

from dotenv import load_dotenv
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-change-in-production")

DATABASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fin_track.db")


def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS category (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
        );
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email_id TEXT UNIQUE,
            amount REAL NOT NULL,
            date TEXT,
            snippet TEXT,
            body TEXT,
            category_id INTEGER REFERENCES category(id)
        );
        CREATE INDEX IF NOT EXISTS idx_txn_email ON transactions(email_id);
        CREATE INDEX IF NOT EXISTS idx_txn_category ON transactions(category_id);
    """)
    # Add body column if missing (existing DBs)
    try:
        conn.execute("ALTER TABLE transactions ADD COLUMN body TEXT")
        conn.commit()
    except sqlite3.OperationalError:
        pass
    conn.close()


@app.route("/")
def index():
    conn = get_db()
    # Last 10 transactions (from DB; uncategorised first)
    rows = conn.execute("""
        SELECT t.id, t.email_id, t.amount, t.date, t.snippet, t.category_id,
               c.name AS category_name
        FROM transactions t
        LEFT JOIN category c ON c.id = t.category_id
        ORDER BY t.category_id IS NOT NULL, t.date DESC, t.id DESC
        LIMIT 10
    """).fetchall()
    categories = conn.execute("SELECT id, name FROM category ORDER BY name").fetchall()
    conn.close()
    transactions = [dict(r) for r in rows]
    return render_template("index.html", transactions=transactions, categories=categories)


@app.route("/fetch", methods=["POST"])
def fetch():
    """Fetch last 10 UPI emails and insert new ones into DB."""
    try:
        from email_service import fetch_last_upi_transactions
        from_filter = os.getenv("IMAP_FROM_FILTER") or None
        items = fetch_last_upi_transactions(max_count=10, from_filter=from_filter)
    except Exception as e:
        flash(f"Could not fetch mail: {e}", "error")
        return redirect(url_for("index"))
    conn = get_db()
    added = 0
    updated = 0
    for item in items:
        try:
            cur = conn.execute(
                "INSERT OR IGNORE INTO transactions (email_id, amount, date, snippet, body) VALUES (?, ?, ?, ?, ?)",
                (
                    item.get("email_id"),
                    item.get("amount") or 0,
                    item.get("date"),
                    item.get("snippet") or "",
                    item.get("body") or "",
                ),
            )
            if conn.total_changes:
                added += 1
            else:
                # Already existed: update amount/date/snippet/body in case parsing improved
                conn.execute(
                    "UPDATE transactions SET amount = ?, date = ?, snippet = ?, body = ? WHERE email_id = ?",
                    (
                        item.get("amount") or 0,
                        item.get("date"),
                        item.get("snippet") or "",
                        item.get("body") or "",
                        item.get("email_id"),
                    ),
                )
                if conn.total_changes:
                    updated += 1
        except Exception:
            pass
    conn.commit()
    conn.close()
    msg = f"Fetched mail. {added} new, {updated} updated." if (added or updated) else "No new transactions from last 10 UPI emails."
    flash(msg)
    return redirect(url_for("index"))


@app.route("/categorise", methods=["POST"])
def categorise():
    txn_id = request.form.get("transaction_id", type=int)
    category_id = request.form.get("category_id", type=int)
    if not txn_id:
        flash("Missing transaction.", "error")
        return redirect(url_for("index"))
    conn = get_db()
    if category_id:
        conn.execute("UPDATE transactions SET category_id = ? WHERE id = ?", (category_id, txn_id))
    else:
        conn.execute("UPDATE transactions SET category_id = NULL WHERE id = ?", (txn_id,))
    conn.commit()
    conn.close()
    flash("Category updated.")
    return redirect(url_for("index"))


@app.route("/transaction/<int:txn_id>")
def transaction_detail(txn_id):
    """Show one transaction with full mail body."""
    conn = get_db()
    row = conn.execute("""
        SELECT t.id, t.amount, t.date, t.body, t.snippet, t.category_id,
               c.name AS category_name
        FROM transactions t
        LEFT JOIN category c ON c.id = t.category_id
        WHERE t.id = ?
    """, (txn_id,)).fetchone()
    conn.close()
    if not row:
        flash("Transaction not found.", "error")
        return redirect(url_for("index"))
    return render_template("transaction_detail.html", t=dict(row))


@app.route("/categories")
def categories_view():
    """View all categories with their transactions (mail snippet, amount, date)."""
    conn = get_db()
    cats = conn.execute(
        "SELECT id, name FROM category ORDER BY name"
    ).fetchall()
    result = []
    for c in cats:
        rows = conn.execute("""
            SELECT id, amount, date
            FROM transactions
            WHERE category_id = ?
            ORDER BY date DESC, id DESC
        """, (c["id"],)).fetchall()
        total = sum(r["amount"] or 0 for r in rows)
        result.append({
            "id": c["id"],
            "name": c["name"],
            "transactions": [dict(r) for r in rows],
            "total": total,
        })
    uncategorised = conn.execute("""
        SELECT id, amount, date
        FROM transactions
        WHERE category_id IS NULL
        ORDER BY date DESC, id DESC
    """).fetchall()
    conn.close()
    return render_template(
        "categories.html",
        categories=result,
        uncategorised=[dict(r) for r in uncategorised],
    )


@app.route("/category/create", methods=["POST"])
def create_category():
    name = (request.form.get("name") or "").strip()
    if not name:
        flash("Category name is required.", "error")
        return redirect(url_for("index"))
    conn = get_db()
    try:
        conn.execute("INSERT INTO category (name) VALUES (?)", (name,))
        conn.commit()
        flash(f"Category '{name}' created.")
    except sqlite3.IntegrityError:
        flash(f"Category '{name}' already exists.", "error")
    conn.close()
    return redirect(url_for("index"))


if __name__ == "__main__":
    init_db()
    app.run(debug=True, port=5000)
