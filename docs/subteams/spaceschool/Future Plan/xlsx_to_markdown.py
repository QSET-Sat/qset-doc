"""Convert Space_School_Purchases.xlsx into GitHub-readable files.

Usage:  python xlsx_to_markdown.py Space_School_Purchases.xlsx
Output: README.md plus one CSV per purchases sheet, in the current folder.
Needs:  pip install openpyxl
"""
import csv
import sys
from datetime import datetime

import openpyxl

STATUSES = ["Not Submitted", "Submitted", "Repaid", "Not Needed"]
STATUS_ICON = {"Not Submitted": "🔴", "Submitted": "🟡", "Repaid": "🟢", "Not Needed": "⚪"}
CATEGORIES = ["Uncategorized", "Teaching Material", "ToastSats", "Balloon Launch"]
CONTINGENCY = 1.15


def money(x):
    return f"${x:,.2f}"


def util_icon(u):
    if u > CONTINGENCY:
        return "🔴"
    if u > 1:
        return "🟠"
    if u >= 0.8:
        return "🟡"
    return "🟢"


def cell_text(v):
    if v is None:
        return ""
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d")
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v).strip()


def md_escape(s):
    return s.replace("|", "\\|").replace("\n", " ")


def table(headers, rows, align=None):
    align = align or ["---"] * len(headers)
    out = ["| " + " | ".join(headers) + " |", "| " + " | ".join(align) + " |"]
    out += ["| " + " | ".join(md_escape(str(c)) for c in r) + " |" for r in rows]
    return "\n".join(out)


def read_purchases(ws):
    headers = [c.value for c in ws[1]]
    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if all(v is None for v in r):
            continue
        rows.append(dict(zip(headers, r)))
    return headers, rows


def main(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    summary = wb["Summary"]
    budget = {}  # category -> allowance, read from the Summary budget table
    for r in range(16, 19):
        name, amount = summary.cell(r, 5).value, summary.cell(r, 6).value
        if name and amount is not None:
            budget[name.strip()] = float(amount)

    md = ["# Space School Purchases", "",
          f"_Generated from `{path.split('/')[-1]}` on {datetime.now():%Y-%m-%d}. "
          "Edit the spreadsheet, then re-run `xlsx_to_markdown.py`._", ""]

    for ws in wb.worksheets:
        if not ws.title.startswith("Purchases"):
            continue
        headers, rows = read_purchases(ws)
        year = ws.title.replace("Purchases", "").strip()
        csv_name = f"purchases_{year}.csv"

        # CSV copy of the raw data (GitHub shows CSVs as searchable tables)
        with open(csv_name, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(headers)
            for row in rows:
                w.writerow([cell_text(row.get(h)) for h in headers])

        md += [f"## {year}", ""]
        if not rows:
            md += ["_No purchases yet._", ""]
            continue

        price = lambda r: float(r.get("Price (CAD)") or 0)
        total = sum(price(r) for r in rows)

        # Repayment status (internal)
        st_rows = []
        for s in STATUSES:
            items = [r for r in rows if (r.get("Repayment Status") or "").strip() == s]
            st_rows.append([f"{STATUS_ICON[s]} {s}", money(sum(map(price, items))), len(items)])
        owed = [r for r in rows if (r.get("Repayment Status") or "").strip() in ("Not Submitted", "Submitted")]
        missing = sum(1 for r in rows if not r.get("Receipt Link"))
        st_rows += [["**Total spent**", f"**{money(total)}**", f"**{len(rows)}**"],
                    ["**Still owed to us** (Not Submitted + Submitted)",
                     f"**{money(sum(map(price, owed)))}**", f"**{len(owed)}**"],
                    ["Missing receipt link", "", missing]]
        md += ["### Repayment status", "",
               table(["Status", "Amount (CAD)", "# Items"], st_rows, ["---", "---:", "---:"]), ""]

        # Spending by category
        spent = {}
        cat_rows = []
        for c in CATEGORIES:
            items = [r for r in rows if (r.get("Budget") or "").strip() == c]
            spent[c] = sum(map(price, items))
            cat_rows.append([c, money(spent[c]), len(items)])
        cat_rows.append(["**Total spent**", f"**{money(total)}**", f"**{len(rows)}**"])
        md += ["### Spending by category", "",
               table(["Category", "Amount (CAD)", "# Items"], cat_rows, ["---", "---:", "---:"]), ""]

        # Budget (only meaningful for the year the Summary budget belongs to)
        if year == "2026-2027" and budget:
            b_rows = []
            for c, amt in budget.items():
                u = spent.get(c, 0) / amt if amt else 0
                b_rows.append([c, money(amt), money(amt * CONTINGENCY),
                               money(amt - spent.get(c, 0)), f"{util_icon(u)} {u:.2%}"])
            tot = sum(budget.values())
            u = total / tot
            b_rows.append(["**Total allowance**", f"**{money(tot)}**", f"**{money(tot * CONTINGENCY)}**",
                           f"**{money(tot - total)}**", f"**{util_icon(u)} {u:.2%}**"])
            md += [f"### Budget {year}", "",
                   table(["Category", "Amount (CAD)", "15% Contingency", "Balance (without leverage)", "Utilization"],
                         b_rows, ["---", "---:", "---:", "---:", "---:"]), "",
                   "Utilization: 🟢 under 80% · 🟡 80–100% · 🟠 100–115% (into contingency) · 🔴 over 115%", ""]

        # Full purchase list
        p_rows = []
        for r in rows:
            status = (r.get("Repayment Status") or "").strip()
            link = r.get("Receipt Link")
            p_rows.append([
                cell_text(r.get("Date")), cell_text(r.get("Budget")), cell_text(r.get("Purchase Description")),
                cell_text(r.get("MPN")), cell_text(r.get("Quantity")), cell_text(r.get("Vendor")),
                cell_text(r.get("Purchased By")), money(price(r)),
                f"{STATUS_ICON.get(status, '')} {status}".strip(),
                f"[Receipt]({link})" if link else "⚠️ missing",
            ])
        md += [f"### Purchases ({len(rows)} items) · [CSV]({csv_name})", "",
               table(["Date", "Budget", "Description", "MPN", "Qty", "Vendor", "Purchased By",
                      "Price (CAD)", "Status", "Receipt"], p_rows,
                     ["---", "---", "---", "---", "---:", "---", "---", "---:", "---", "---"]), ""]

    with open("README.md", "w", encoding="utf-8") as f:
        f.write("\n".join(md))
    print("Wrote README.md and CSV files.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Space_School_Purchases.xlsx")
