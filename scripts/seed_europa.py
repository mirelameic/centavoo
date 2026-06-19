#!/usr/bin/env python3
"""
Seed the "Europa 2025" trip from gastos-europa.xlsx.

Reads the two sheets of the spreadsheet and generates `public/europa.json`,
which the app imports to populate the local database (Dexie / IndexedDB).

Fidelity: on the `during` sheet, each expense's category is encoded in the FONT
COLOR of the description cell. Each color sums exactly to its category total in
the spreadsheet itself, so we use the color as the source of truth.

Usage:
    python3 -m venv scripts/.venv
    scripts/.venv/bin/pip install openpyxl
    scripts/.venv/bin/python scripts/seed_europa.py
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

import openpyxl
import openpyxl.utils as U

# --- paths --------------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
XLSX = Path.home() / "Desktop" / "gastos-europa.xlsx"
OUT = ROOT / "public" / "europa.json"

TRIP_ID = "trip_europa_2025"  # internal id (kept stable for upsert); display name is 2026
YEAR = 2026
NOW = datetime.now().isoformat(timespec="seconds")

# --- categories (id, name, color, emoji) --------------------------------------
# Colors for Transporte..Outros are the same ones Mirela used in the spreadsheet.
CATEGORIES = [
    ("cat_hospedagem", "Hospedagem", "#0CA678", "🏨"),
    ("cat_passagem", "Passagem", "#4263EB", "✈️"),
    ("cat_transporte", "Transporte", "#FF9900", "🚕"),
    ("cat_alimentacao", "Alimentação", "#9900FF", "🍽️"),
    ("cat_compras", "Compras", "#4A86E8", "🛍️"),
    ("cat_brindes", "Brindes", "#00B5C7", "🎁"),  # her cyan (00FFFF) darkened for contrast
    ("cat_turismo", "Turismo", "#E6B800", "🎟️"),  # her yellow (FFFF00) darkened
    ("cat_genericos", "Genéricos de viagem", "#FF0000", "🧳"),
    ("cat_cannabis", "Cannabis", "#00C000", "🌿"),  # her green (00FF00) darkened
    ("cat_outros", "Outros", "#FF00FF", "🔖"),
]

# Font color (ARGB in the spreadsheet) -> category id, for the `during` sheet.
FONT_TO_CAT = {
    "FF4A86E8": "cat_compras",
    "FF9900FF": "cat_alimentacao",
    "FF00FF00": "cat_cannabis",
    "FFFF0000": "cat_genericos",
    "FF00FFFF": "cat_brindes",
    "FFFF9900": "cat_transporte",
    "FFFF8000": "cat_transporte",
    "FFFF00FF": "cat_outros",
    "FFFFFF00": "cat_turismo",
}

transactions: list[dict] = []
_counter = 0


def add_tx(period, date, description, amount, category_id, kind, is_iof, split_count, city, raw):
    global _counter
    _counter += 1
    transactions.append(
        {
            "id": f"tx_{_counter:04d}",
            "tripId": TRIP_ID,
            "period": period,
            "date": date,                       # "YYYY-MM-DD" or None
            "description": str(description).strip(),
            "amount": round(float(amount), 2),  # signed: expense +, refund -
            "categoryId": category_id,
            "kind": kind,                       # EXPENSE | REFUND | IOF_REFUND
            "isIof": is_iof,
            "splitCount": int(split_count),     # 1 = no split; full amount stays in `amount`
            "city": city,                       # where the transaction happened (null for BEFORE)
            "rawText": str(raw).strip(),
            "createdAt": NOW,
        }
    )


def font_rgb(cell):
    c = cell.font.color
    if not c or c.type != "rgb":
        return None
    return c.rgb


# ------------------------------------------------------------------------------
def main():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    before = wb["before"]
    during = wb["during"]

    # ===== BEFORE sheet =======================================================
    # Lodging: A=name, B=total, C=already-divided value -> split = total / divided
    for r in range(3, 8):
        name, total, divided = before[f"A{r}"].value, before[f"B{r}"].value, before[f"C{r}"].value
        if not name or total is None:
            continue
        split = round(total / divided) if divided else 1
        add_tx("BEFORE", None, name, total, "cat_hospedagem", "EXPENSE", False, split, None, name)

    # Flights: F=name, G=value
    for r in range(3, 8):
        name, val = before[f"F{r}"].value, before[f"G{r}"].value
        if not name or val is None:
            continue
        add_tx("BEFORE", None, name, val, "cat_passagem", "EXPENSE", False, 1, None, name)

    # "outros" (H=value, I=label): refund (estorno) and baggage
    for r in range(3, 8):
        val, label = before[f"H{r}"].value, before[f"I{r}"].value
        if val is None or not label:
            continue
        if val < 0:
            add_tx("BEFORE", None, label, val, "cat_outros", "REFUND", False, 1, None, label)
        else:
            add_tx("BEFORE", None, label, val, "cat_genericos", "EXPENSE", False, 1, None, label)

    # "OUTROS" (K=name, L=value): museum, seats, travel things
    before_outros_cat = {
        "van gogh museum": "cat_turismo",
        "assentos avião": "cat_genericos",
        "coisas viagem ml": "cat_genericos",
    }
    for r in range(3, 9):
        name, val = before[f"K{r}"].value, before[f"L{r}"].value
        if not name or val is None or str(name).strip().lower() == "total":
            continue
        cat = before_outros_cat.get(str(name).strip().lower(), "cat_genericos")
        add_tx("BEFORE", None, name, val, cat, "EXPENSE", False, 1, None, name)

    # ===== DURING sheet =======================================================
    starts = ["A", "E", "I", "M", "Q", "U", "Y", "AC", "AG", "AK",
              "AO", "AS", "AW", "BA", "BE", "BI", "BM", "BQ"]
    nextcol = lambda c: U.get_column_letter(U.column_index_from_string(c) + 1)
    itinerary = []
    unmatched_colors = defaultdict(float)

    for s in starts:
        lc, vc = s, nextcol(s)
        header = during[f"{lc}1"].value or ""
        m = re.search(r"\((\d{2})/(\d{2})\)", str(header))
        date = f"{YEAR}-{m.group(2)}-{m.group(1)}" if m else None
        # City: text after "—"; drop "Ida /" / "Volta /" prefixes by taking the last segment.
        loc = str(header).split("—")[-1].strip() if "—" in str(header) else ""
        city = loc.split("/")[-1].strip() if loc else None
        # Departure day ("Ida / ..."): the spending happened in SP (the origin).
        if loc and loc.lower().startswith("ida"):
            city = "SP"
        if date:
            itinerary.append(f"{m.group(1)}/{m.group(2)} {city or ''}".strip())

        for r in range(4, 27):
            cell = during[f"{lc}{r}"]
            label, val = cell.value, during[f"{vc}{r}"].value
            if label is None and val is None:
                continue
            if isinstance(label, str) and label.strip().lower() in ("gastos", "reembolsos"):
                continue
            if isinstance(label, str) and label.upper().startswith("TOTAL"):
                break
            if val is None:
                continue

            if str(label).strip().lower().startswith("iof"):
                # IOF refund line (negative value, no color)
                add_tx("DURING", date, label, val, None, "IOF_REFUND", True, 1, city, label)
            else:
                rgb = font_rgb(cell)
                cat = FONT_TO_CAT.get(rgb)
                if cat is None:
                    unmatched_colors[rgb] += float(val)
                add_tx("DURING", date, label, val, cat, "EXPENSE", False, 1, city, label)

    # ===== auto-categorization rules (seeded from the already-colored labels) ==
    # description (lowercase) -> categoryId, so the app can suggest a category on
    # future imports. Built only from DURING expenses already categorized by color.
    rule_map: dict[str, str] = {}
    for t in transactions:
        if t["kind"] == "EXPENSE" and t["categoryId"] and t["period"] == "DURING":
            rule_map.setdefault(t["description"].lower(), t["categoryId"])
    # a few useful generic rules (lower priority)
    generic = {
        "uber": "cat_transporte", "mercado": "cat_alimentacao", "coffee": "cat_alimentacao",
        "café": "cat_alimentacao", "comida": "cat_alimentacao", "farmácia": "cat_outros",
        "ímã": "cat_brindes", "brindes": "cat_brindes", "assento": "cat_genericos",
        "laundry": "cat_genericos", "esim": "cat_genericos",
    }
    rules = [{"keyword": k, "categoryId": v, "priority": 10} for k, v in sorted(rule_map.items())]
    rules += [{"keyword": k, "categoryId": v, "priority": 1}
              for k, v in generic.items() if k not in rule_map]

    # ===== validation =========================================================
    def s(pred):
        return round(sum(t["amount"] for t in transactions if pred(t)), 2)

    during_gastos = s(lambda t: t["period"] == "DURING" and t["amount"] > 0)
    during_reemb = s(lambda t: t["period"] == "DURING" and t["amount"] < 0)
    # "before" total: lodging counts as your share (amount/splitCount); rest in full.
    before_total = round(
        sum(t["amount"] / t["splitCount"] if t["categoryId"] == "cat_hospedagem" else t["amount"]
            for t in transactions if t["period"] == "BEFORE"),
        2,
    )

    by_cat = defaultdict(float)
    for t in transactions:
        if t["period"] == "DURING" and t["amount"] > 0:
            by_cat[t["categoryId"]] += t["amount"]

    print("=" * 60)
    print(f"Transactions: {len(transactions)}  (before + during)")
    print(f"DURING expenses  = {during_gastos:>9.2f}   (sheet: 10754.85)")
    print(f"DURING refunds   = {during_reemb:>9.2f}   (sheet:  -311.29)")
    print(f"BEFORE total     = {before_total:>9.2f}   (sheet: 14874.43)")
    print("By category (DURING, gross):")
    for cid, name, _, _ in CATEGORIES:
        if by_cat.get(cid):
            print(f"   {name:22s} {by_cat[cid]:>9.2f}")
    cities = sorted({t["city"] for t in transactions if t["city"]})
    print(f"Cities: {', '.join(cities)}")
    if unmatched_colors:
        print("⚠️  Unmapped colors (check):")
        for rgb, tot in unmatched_colors.items():
            print(f"   {rgb}  sum={tot:.2f}")
    print("=" * 60)

    # ===== write JSON =========================================================
    trip = {
        "id": TRIP_ID,
        "name": "Europa 2026",
        "destination": "Espanha · Grécia · Holanda",
        "startDate": f"{YEAR}-05-17",
        "endDate": f"{YEAR}-06-03",
        "currency": "BRL",
        "notes": "Imported from spreadsheet. Itinerary: " + " · ".join(itinerary),
        "createdAt": NOW,
    }
    payload = {
        "version": 3,
        "generatedFrom": "gastos-europa.xlsx",
        "categories": [
            {"id": i, "name": n, "color": c, "icon": e, "sortOrder": idx}
            for idx, (i, n, c, e) in enumerate(CATEGORIES)
        ],
        "rules": rules,
        "trips": [trip],
        "transactions": transactions,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✅ Wrote {OUT}  ({len(transactions)} transactions, {len(rules)} rules)")


if __name__ == "__main__":
    main()
