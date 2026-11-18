#!/usr/bin/env python3
"""Deterministic portfolio allocation and concentration calculator.

Input JSON example:
{
  "cash": 47000,
  "positions": [
    {"symbol":"SBER","asset_class":"equity","issuer":"Sber","sector":"Financials","market_value":120000},
    {"symbol":"OFZ","asset_class":"bond","issuer":"Russian Federation","sector":"Government","market_value":100000,"is_ofz":true}
  ],
  "purchases": [
    {"symbol":"SBER","asset_class":"equity","issuer":"Sber","sector":"Financials","amount":10000}
  ]
}

The script assumes purchases are funded from cash and do not change total portfolio value.
"""

import argparse
import json
import sys
from collections import defaultdict

DEFAULT_BANDS = {
    "equity": (0.35, 0.55),
    "bond": (0.35, 0.55),
    "liquidity": (0.05, 0.15),
}


def normalize_positions(data):
    positions = []
    for p in data.get("positions", []):
        q = dict(p)
        q["market_value"] = float(q.get("market_value", 0.0))
        positions.append(q)
    return positions


def allocation(positions, cash):
    total = cash + sum(p["market_value"] for p in positions)
    by_class = defaultdict(float)
    by_issuer = defaultdict(float)
    by_sector = defaultdict(float)

    for p in positions:
        value = p["market_value"]
        cls = p.get("asset_class", "other")
        by_class[cls] += value
        issuer = p.get("issuer") or p.get("symbol", "UNKNOWN")
        by_issuer[issuer] += value
        if cls == "equity":
            by_sector[p.get("sector", "Unknown")] += value

    by_class["liquidity"] += cash

    def weights(bucket):
        if total <= 0:
            return {k: 0.0 for k in bucket}
        return {k: v / total for k, v in bucket.items()}

    return {
        "total": total,
        "cash": cash,
        "class_weights": weights(by_class),
        "issuer_weights": weights(by_issuer),
        "equity_sector_weights": weights(by_sector),
    }


def apply_purchases(positions, cash, purchases):
    positions = [dict(p) for p in positions]
    idx = {(p.get("symbol"), p.get("issuer")): p for p in positions}
    spent = 0.0

    for buy in purchases:
        amount = float(buy.get("amount", 0.0))
        if amount < 0:
            raise ValueError("purchase amount cannot be negative")
        spent += amount
        key = (buy.get("symbol"), buy.get("issuer"))
        if key in idx:
            idx[key]["market_value"] += amount
        else:
            p = dict(buy)
            p["market_value"] = amount
            p.pop("amount", None)
            positions.append(p)
            idx[key] = p

    if spent > cash + 1e-9:
        raise ValueError(f"purchases exceed cash: spent={spent:.2f}, cash={cash:.2f}")
    return positions, cash - spent


def checks(snapshot):
    out = []
    cw = snapshot["class_weights"]
    for cls, (lo, hi) in DEFAULT_BANDS.items():
        w = cw.get(cls, 0.0)
        if w < lo:
            out.append({"type": "asset_class_underweight", "name": cls, "weight": w, "band": [lo, hi]})
        elif w > hi:
            out.append({"type": "asset_class_overweight", "name": cls, "weight": w, "band": [lo, hi]})

    for issuer, w in snapshot["issuer_weights"].items():
        if issuer != "Russian Federation" and w > 0.10:
            out.append({"type": "issuer_concentration", "name": issuer, "weight": w, "limit": 0.10})

    for sector, w in snapshot["equity_sector_weights"].items():
        if w > 0.25:
            out.append({"type": "equity_sector_concentration", "name": sector, "weight": w, "limit": 0.25})

    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", nargs="?", help="JSON file, or stdin if omitted")
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = json.load(sys.stdin)

    positions = normalize_positions(data)
    cash = float(data.get("cash", 0.0))
    before = allocation(positions, cash)
    after_positions, after_cash = apply_purchases(positions, cash, data.get("purchases", []))
    after = allocation(after_positions, after_cash)

    result = {
        "before": before,
        "before_checks": checks(before),
        "after": after,
        "after_checks": checks(after),
    }
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
