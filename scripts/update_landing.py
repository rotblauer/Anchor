#!/usr/bin/env python3
"""Regenerates docs/index.html (the GitHub Pages landing page) from the app's
bundled databases, so the page always reflects the real place catalog.

Run from the repo root whenever places.json / islands.json change:

    python3 scripts/update_landing.py
"""
import json
import datetime
import html
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent.parent
PLACES = json.loads((ROOT / "AnchorCore/Sources/AnchorCore/Resources/places.json").read_text())["places"]
CONTENT = json.loads((ROOT / "AnchorCore/Sources/AnchorCore/Resources/islands.json").read_text())
POIS = json.loads((ROOT / "AnchorCore/Sources/AnchorCore/Resources/pois.json").read_text())["pois"]
OUT = ROOT / "docs/index.html"

TYPE_LABELS = {
    "anchorage": "Anchorage",
    "dock": "Dock",
    "marina": "Marina",
    "anchorage_dock": "Anchorage + Dock",
}

# ---------- Stats ----------
stays = [p for p in PLACES if not p.get("advisory")]
advisories = [p for p in PLACES if p.get("advisory")]
n_anchorages = sum(1 for p in stays if p["type"] in ("anchorage", "anchorage_dock"))
n_docks = sum(1 for p in stays if p["type"] in ("dock", "anchorage_dock"))
n_marinas = sum(1 for p in stays if p["type"] == "marina")
n_sources = len({s for p in PLACES for s in p.get("sources", [])})

stats = [
    (str(len(stays)), "places to stay"),
    (str(n_anchorages), "anchorages"),
    (str(n_docks), "island &amp; town docks"),
    (str(n_marinas), "marinas"),
    (str(len(POIS)), "points of interest"),
    (str(len(CONTENT["islands"])), "islands to explore"),
    ("8", "day wind outlook"),
]

poi_kinds = {}
for p in POIS:
    poi_kinds[p["kind"]] = poi_kinds.get(p["kind"], 0) + 1
KIND_LABELS = {"lighthouse": "lighthouses", "shipwreck": "shipwrecks", "sea_cave": "sea-cave areas",
               "historic": "historic sites", "natural": "natural wonders"}
lore_breakdown = ", ".join(
    f"{n} {KIND_LABELS.get(k, k)}"
    for k, n in sorted(poi_kinds.items(), key=lambda kv: -kv[1])
)
stats_html = "\n".join(
    f'      <div class="stat"><span class="stat-n">{n}</span><span class="stat-l">{label}</span></div>'
    for n, label in stats
)

# ---------- Place directory ----------
def island_sort_key(name):
    return (name.startswith("Mainland"), name)

by_island = {}
for p in PLACES:
    by_island.setdefault(p["island"], []).append(p)

directory_parts = []
for island in sorted(by_island, key=island_sort_key):
    rows = []
    for p in sorted(by_island[island], key=lambda x: x["name"]):
        chips = [f'<span class="chip chip-{p["type"]}">{TYPE_LABELS[p["type"]]}</span>']
        if p.get("advisory"):
            chips.append('<span class="chip chip-advisory">Advisory</span>')
        best = html.escape(p.get("bestFor", "") or "")
        rows.append(
            f'        <li><span class="place-name">{html.escape(p["name"])}</span> '
            f'{" ".join(chips)}'
            + (f'<span class="place-best">{best}</span>' if best else "")
            + "</li>"
        )
    directory_parts.append(
        f'      <div class="island-group">\n'
        f'        <h4>{html.escape(island)}</h4>\n'
        f'        <ul>\n' + "\n".join(rows) + "\n        </ul>\n      </div>"
    )
directory_html = "\n".join(directory_parts)

generated = datetime.date.today().strftime("%B %-d, %Y")

TEMPLATE = Template(r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Apostle Anchor — wind-smart anchoring in the Apostle Islands</title>
<meta name="description" content="An iOS app that matches multi-day wind forecasts against the real shelter of every documented anchorage, dock, and marina in Apostle Islands National Lakeshore.">
<link rel="icon" href="assets/icon.png">
<style>
  :root {
    --navy: #0b2a44; --navy-deep: #071c30; --teal: #0b6e7f; --teal-bright: #128fa3;
    --sand: #ede0bb; --ink: #16283a; --paper: #f7f5ef; --card: #ffffff;
    --muted: #5b6b7a; --line: #dfd9c9;
    --good: #2e9e56; --advisory: #855aa0;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --ink: #e8eef4; --paper: #0a1520; --card: #12222f; --muted: #9fb0bf;
      --line: #22384a;
    }
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
         color: var(--ink); background: var(--paper); }
  a { color: var(--teal-bright); }
  .wrap { max-width: 1040px; margin: 0 auto; padding: 0 24px; }

  header { background: linear-gradient(160deg, var(--navy-deep) 0%, var(--navy) 55%, var(--teal) 130%);
           color: #fff; overflow: hidden; }
  .hero { display: flex; align-items: center; gap: 48px; padding: 72px 0 64px; flex-wrap: wrap; }
  .hero-text { flex: 1 1 380px; }
  .hero img.appicon { width: 88px; height: 88px; border-radius: 20px;
                      box-shadow: 0 8px 28px rgba(0,0,0,.45); margin-bottom: 20px; }
  h1 { font-size: 44px; line-height: 1.1; letter-spacing: -0.5px; }
  .tagline { font-size: 21px; color: #cfe3ea; margin: 14px 0 26px; max-width: 34ch; }
  .cta { display: inline-block; background: #fff; color: var(--navy); font-weight: 700;
         padding: 12px 22px; border-radius: 999px; text-decoration: none; margin: 0 10px 10px 0; }
  .cta.ghost { background: transparent; color: #fff; border: 2px solid rgba(255,255,255,.55); }
  .hero-shot { flex: 0 1 300px; text-align: center; }
  .phone { width: 280px; border-radius: 36px; box-shadow: 0 24px 60px rgba(0,0,0,.5);
           border: 6px solid #0d1117; }

  .stats { display: flex; flex-wrap: wrap; gap: 8px 40px; justify-content: center;
           padding: 26px 0; border-bottom: 1px solid var(--line); }
  .stat { text-align: center; padding: 6px 0; }
  .stat-n { display: block; font-size: 34px; font-weight: 800; color: var(--teal-bright); }
  .stat-l { font-size: 13px; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); }

  section { padding: 56px 0 8px; }
  h2 { font-size: 30px; margin-bottom: 8px; }
  .lede { color: var(--muted); max-width: 62ch; margin-bottom: 32px; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 18px; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 22px; }
  .card .emoji { font-size: 26px; }
  .card h3 { font-size: 18px; margin: 10px 0 6px; }
  .card p { font-size: 15px; color: var(--muted); }

  .shots { display: flex; gap: 26px; justify-content: center; flex-wrap: wrap; padding: 16px 0 8px; }
  .shots figure { text-align: center; }
  .shots img { width: 250px; border-radius: 30px; border: 5px solid #0d1117;
               box-shadow: 0 16px 40px rgba(10,30,50,.35); }
  .shots figcaption { font-size: 14px; color: var(--muted); margin-top: 10px; }

  .directory { columns: 2; column-gap: 40px; }
  @media (max-width: 720px) { .directory { columns: 1; } }
  .island-group { break-inside: avoid; margin-bottom: 26px; }
  .island-group h4 { font-size: 16px; color: var(--teal-bright); margin-bottom: 6px; }
  .island-group ul { list-style: none; }
  .island-group li { font-size: 15px; padding: 5px 0; border-bottom: 1px dashed var(--line); }
  .place-name { font-weight: 600; }
  .place-best { display: block; font-size: 13px; color: var(--muted); }
  .chip { display: inline-block; font-size: 11px; font-weight: 700; padding: 1px 8px;
          border-radius: 999px; margin-left: 6px; vertical-align: 2px;
          background: rgba(18,143,163,.14); color: var(--teal-bright); }
  .chip-advisory { background: rgba(133,90,160,.16); color: var(--advisory); }

  .honesty { background: var(--card); border: 1px solid var(--line); border-radius: 16px;
             padding: 26px; margin-top: 8px; }
  .honesty ul { margin: 10px 0 0 22px; font-size: 15px; color: var(--muted); }

  .disclaimer { border-left: 4px solid #d9822b; padding: 14px 18px; background: rgba(217,130,43,.09);
                border-radius: 0 10px 10px 0; font-size: 15px; margin: 26px 0; }

  footer { margin-top: 56px; padding: 30px 0 44px; border-top: 1px solid var(--line);
           font-size: 14px; color: var(--muted); }
  footer code { background: var(--card); border: 1px solid var(--line); padding: 1px 7px;
                border-radius: 6px; font-size: 13px; }
</style>
</head>
<body>

<header>
  <div class="wrap hero">
    <div class="hero-text">
      <img class="appicon" src="assets/icon.png" alt="Apostle Anchor app icon">
      <h1>Apostle Anchor</h1>
      <p class="tagline">Know where to drop the hook before the wind makes the call for you.</p>
      <a class="cta" href="https://github.com/rotblauer/Anchor">View on GitHub</a>
      <a class="cta ghost" href="#how">How it works</a>
    </div>
    <div class="hero-shot">
      <img class="phone" src="assets/shot-map.jpg" alt="The planning map: wind-field arrows over the Apostle Islands with rated anchorage pins">
    </div>
  </div>
</header>

<div class="wrap">
  <div class="stats">
$STATS
  </div>

  <section id="how">
    <h2>Reads the wind the way Superior sailors do</h2>
    <p class="lede">Apostle Anchor is an iOS app for cruising Apostle Islands National Lakeshore — 21 islands on Lake Superior where the evening's big question is always the same: <em>given the forecast, where do we stay tonight?</em></p>
    <div class="cards">
      <div class="card"><span class="emoji">🧭</span><h3>Real shelter profiles</h3>
        <p>Every place carries a 16-direction shelter fingerprint and wave-fetch map built from its actual geography — bluffs, sandspits, breakwalls, and the islands that block a sea from building.</p></div>
      <div class="card"><span class="emoji">🌙</span><h3>Overnight-weighted scoring</h3>
        <p>Hourly wind and gust forecasts are scored against each profile, weighting the hours you actually swing at anchor and grading every night from Excellent to Avoid.</p></div>
      <div class="card"><span class="emoji">⚠️</span><h3>The lee-shore rule</h3>
        <p>Strong wind onto an exposed shore caps the score no matter how nice the beach is. Superior forgives many things; a lee shore isn't one of them.</p></div>
      <div class="card"><span class="emoji">🗓️</span><h3>Multi-night outlooks</h3>
        <p>Night-by-night squares project a week out with a “good for N nights” badge — so a one-night wonder and a stay-all-week harbor are easy to tell apart.</p></div>
    </div>
  </section>

  <section>
    <h2>Plan, browse, explore</h2>
    <p class="lede">A live wind-field map with a play-through time scrubber, ranked picks for any night, rich detail pages with protection roses and gust charts, marine alerts from NOAA — plus island stories, lighthouses, shipwrecks, and singing sands for the days you're not going anywhere.</p>
    <div class="shots">
      <figure><img src="assets/shot-map.jpg" alt="Plan tab: wind overlay and rated pins"><figcaption>Wind-field planning map</figcaption></figure>
      <figure><img src="assets/shot-places.jpg" alt="Places tab: searchable catalog with per-night ratings"><figcaption>Every place, rated per night</figcaption></figure>
      <figure><img src="assets/shot-explore.jpg" alt="Explore tab: island stories and park lore"><figcaption>Island lore &amp; lighthouses</figcaption></figure>
    </div>
  </section>

  <section>
    <h2>The catalog</h2>
    <p class="lede">$PLACE_COUNT documented places — no invented pins on random coastline. Compiled from NPS boating guidance, marina listings, NOAA Coast Pilot, and published Lake Superior cruising references, then adversarially verified for existence, coordinates, and shelter geometry. Purple advisory entries are closures and day-stop-only areas the app will never recommend for the night.</p>
    <div class="directory">
$DIRECTORY
    </div>
  </section>

  <section>
    <h2>Data &amp; honesty</h2>
    <div class="honesty">
      <ul>
        <li><strong>Forecasts:</strong> Open-Meteo hourly 10&nbsp;m wind, gusts, and direction, in knots, 8 days out.</li>
        <li><strong>Marine alerts:</strong> Live Small Craft Advisories and Gale Warnings from NOAA/NWS for the five nearshore zones around the islands.</li>
        <li><strong>Places:</strong> Every entry cites its sources in-app. $ADVISORY_COUNT advisory entries flag wildlife closures and day-use-only areas.</li>
        <li><strong>Lore:</strong> $LORE_BREAKDOWN — every story fact-checked and sourced, browsable on the map and in Explore.</li>
        <li><strong>Times:</strong> Always shown in the islands' local time, wherever your phone thinks it is.</li>
        <li><strong>Offline:</strong> The last forecast is cached, because the outer islands don't do bars.</li>
      </ul>
    </div>
    <div class="disclaimer"><strong>Not for navigation.</strong> Ratings are planning guidance, not gospel. Carry charts, check the NOAA marine forecast, and make your own seamanship calls — Lake Superior is cold, big, and changes faster than any forecast.</div>
  </section>

  <footer>
    Built with SwiftUI, MapKit, and Swift Charts · iOS 17+ · Open source on <a href="https://github.com/rotblauer/Anchor">GitHub</a><br>
    Page generated from the app's databases on $GENERATED — regenerate with <code>python3 scripts/update_landing.py</code>
  </footer>
</div>

</body>
</html>
""")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(TEMPLATE.substitute(
    STATS=stats_html,
    DIRECTORY=directory_html,
    PLACE_COUNT=str(len(PLACES)),
    ADVISORY_COUNT=str(len(advisories)),
    LORE_BREAKDOWN=lore_breakdown,
    GENERATED=generated,
))
print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes) — {len(PLACES)} places, {len(CONTENT['islands'])} islands")
