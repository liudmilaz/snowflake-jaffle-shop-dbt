"""Reconcile Lightdash metrics against the Snowflake semantic view (sv_order_economics).

The semantic view is the reference implementation; the Lightdash metrics in
models/marts/_marts__models.yml are the BI-facing copy. This fails (exit 1)
if any metric differs at any checked grain, so the two cannot drift silently.

Needs: `snow` connection (SNOW_CONN, default jaffle_shop), LIGHTDASH_URL,
LIGHTDASH_API_KEY (personal access token), LIGHTDASH_PROJECT. Run from CI after deploy.
"""
import csv, io, json, os, subprocess, sys, time, urllib.request

CONN = os.environ.get("SNOW_CONN", "jaffle_shop")
URL = os.environ.get("LIGHTDASH_URL", "http://localhost:8080")
KEY, PROJECT = os.environ["LIGHTDASH_API_KEY"], os.environ["LIGHTDASH_PROJECT"]
SV = os.environ.get("SEMANTIC_VIEW", "PC_DBT_DB.dbt_LZolotukhina.sv_order_economics")
TOL = 1e-6

# (explore, [sv dimensions -> lightdash dimension ids], {sv metric: lightdash metric id})
CHECKS = [
    ("dim_customers", {}, {"total_orders": "fct_orders_total_orders",
                           "avg_order_value": "fct_orders_avg_order_value",
                           "true_avg_order_value": "fct_orders_true_avg_order_value",
                           "orders_per_customer": "dim_customers_orders_per_customer",
                           "total_customers": "dim_customers_total_customers"}),
    ("fct_orders", {"order_status": "fct_orders_status"},
                   {"total_orders": "fct_orders_total_orders",
                    "avg_order_value": "fct_orders_avg_order_value",
                    "true_avg_order_value": "fct_orders_true_avg_order_value"}),
]

def sv_rows(dims, metrics):
    q = f"select * from semantic_view({SV} metrics {', '.join(metrics)}" + (f" dimensions {', '.join(dims)}" if dims else "") + ")"
    out = subprocess.run(["snow", "sql", "-c", CONN, "-q", q, "--format", "csv"], capture_output=True, text=True, check=True).stdout
    return {tuple(r.get(d.upper()) for d in dims): {m: r[m.upper()] for m in metrics} for r in csv.DictReader(io.StringIO(out))}

def api(path, body=None):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"ApiKey {KEY}", "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))["results"]

def ld_rows(explore, dims, metrics):
    q = api(f"/api/v2/projects/{PROJECT}/query/metric-query", {"context": "api", "query": {
        "exploreName": explore, "dimensions": list(dims.values()), "metrics": list(metrics.values()),
        "filters": {}, "sorts": [], "limit": 500, "tableCalculations": []}})["queryUuid"]
    for _ in range(30):
        r = api(f"/api/v2/projects/{PROJECT}/query/{q}")
        if r["status"] == "ready": break
        time.sleep(1)
    return {tuple(str(row[d]["value"]["raw"]) for d in dims.values()): {m: row[i]["value"]["raw"] for m, i in metrics.items()} for row in r["rows"]}

bad = 0
for explore, dims, metrics in CHECKS:
    sv, ld = sv_rows(list(dims), list(metrics)), ld_rows(explore, dims, metrics)
    for key, sv_vals in sv.items():
        for m, sv_v in sv_vals.items():
            a, b = float(sv_v or 0), float((ld.get(key, {}).get(m)) or 0)
            ok = abs(a - b) <= TOL
            bad += not ok
            print(("OK  " if ok else "FAIL"), explore, dict(zip(dims, key)), m, f"sv={a:.6f} lightdash={b:.6f}")
sys.exit(1 if bad else 0)
