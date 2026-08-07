#!/usr/bin/env python3
"""Regenerates docs/index.html (the GitHub Pages landing page) from the app's
bundled databases — including the interactive #explore map, which embeds every
place and point of interest so the web content always matches the app.

Run from the repo root whenever places.json / islands.json / pois.json change:

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

stats = [
    (str(len(stays)), "places to stay"),
    (str(n_anchorages), "anchorages"),
    (str(n_docks), "island &amp; town docks"),
    (str(n_marinas), "marinas"),
    (str(len(POIS)), "points of interest"),
    (str(len(CONTENT["islands"])), "islands to explore"),
    ("8", "day wind outlook"),
]
stats_html = "\n".join(
    f'      <div class="stat"><span class="stat-n">{n}</span><span class="stat-l">{label}</span></div>'
    for n, label in stats
)

poi_kinds = {}
for p in POIS:
    poi_kinds[p["kind"]] = poi_kinds.get(p["kind"], 0) + 1
KIND_LABELS = {"lighthouse": "lighthouses", "shipwreck": "shipwrecks", "sea_cave": "sea-cave areas",
               "historic": "historic sites", "natural": "natural wonders"}
lore_breakdown = ", ".join(
    f"{n} {KIND_LABELS.get(k, k)}"
    for k, n in sorted(poi_kinds.items(), key=lambda kv: -kv[1])
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

# ---------- Explore map payloads ----------
def depth_label(p):
    low, high = p.get("depthFtMin"), p.get("depthFtMax")
    if low and high and low != high:
        return f"{int(low)}–{int(high)} ft"
    if low:
        return f"≈{int(low)} ft"
    if high:
        return f"≈{int(high)} ft"
    return None

def place_payload(p):
    dock = p.get("dock") or {}
    return {
        "n": p["name"], "i": p["island"], "t": p["type"],
        "lat": p["lat"], "lon": p["lon"],
        "d": p.get("description", ""),
        "best": p.get("bestFor") or "",
        "depth": depth_label(p) or "",
        "bottom": (p.get("bottom") or "").capitalize(),
        "holding": (p.get("holding") or "").capitalize() if p["type"] != "marina" else "",
        "haz": p.get("hazards") or "",
        "facts": p.get("funFacts", [])[:2],
        "amen": p.get("amenities", [])[:6],
        "dock": dock.get("notes") or "",
        "adv": bool(p.get("advisory")),
        "src": p.get("sources", []),
    }

def poi_payload(p):
    return {
        "n": p["name"], "i": p["island"], "k": p["kind"],
        "lat": p["lat"], "lon": p["lon"],
        "tag": p.get("tagline", ""),
        "story": p.get("story", ""),
        "tips": p.get("visitTips") or "",
        "facts": p.get("funFacts", []),
        "src": p.get("sources", []),
    }

def js_json(obj):
    # "</" would terminate the <script> tag if left raw.
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")

explore_data = (
    "var PLACES=" + js_json([place_payload(p) for p in PLACES]) + ";\n"
    "var POIS=" + js_json([poi_payload(p) for p in POIS]) + ";"
)

generated = datetime.date.today().strftime("%B %-d, %Y")

TEMPLATE = Template(r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Apostle Anchor — wind-smart anchoring in the Apostle Islands</title>
<meta name="description" content="An iOS app that matches multi-day wind forecasts against the real shelter of every documented anchorage, dock, and marina in Apostle Islands National Lakeshore — with an interactive map of all of it.">
<link rel="icon" href="assets/icon.png">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css">
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css">
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

  /* ---------- Explore map ---------- */
  #map { height: 68vh; min-height: 440px; border-radius: 16px; border: 1px solid var(--line);
         box-shadow: 0 10px 30px rgba(10,30,50,.18); }
  .map-controls { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 14px; }
  .map-controls input { flex: 1 1 200px; max-width: 280px; padding: 9px 14px; border-radius: 999px;
                        border: 1px solid var(--line); background: var(--card); color: var(--ink);
                        font-size: 14px; outline: none; }
  .fchip { border: none; cursor: pointer; font: 600 13px/1 -apple-system, sans-serif;
           padding: 8px 13px; border-radius: 999px; background: var(--card); color: var(--muted);
           border: 1px solid var(--line); }
  .fchip.on { color: #fff; border-color: transparent; }
  .map-note { font-size: 13px; color: var(--muted); margin-top: 10px; }
  .pin { width: 22px; height: 22px; display: flex; align-items: center; justify-content: center;
         border: 1.5px solid #fff; box-shadow: 0 1px 4px rgba(0,0,0,.5); }
  .pin-circle { border-radius: 50%; }
  .pin-diamond { border-radius: 5px; transform: rotate(45deg); }
  .pin-diamond .pin-glyph { transform: rotate(-45deg); display: flex; }
  .pin svg { width: 13px; height: 13px; stroke: #fff; fill: none;
             stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
  .leaflet-popup-content-wrapper, .leaflet-popup-tip { background: var(--card); color: var(--ink); }
  .leaflet-popup-content { margin: 14px 16px; font: 14px/1.5 -apple-system, sans-serif; }
  .popup-body { max-height: 300px; overflow-y: auto; padding-right: 4px; }
  .popup-body h3 { font-size: 16px; margin-bottom: 2px; }
  .popup-island { font-size: 12px; color: var(--muted); margin-bottom: 6px; }
  .popup-tag { font-weight: 600; font-size: 13px; margin-bottom: 8px; }
  .popup-body p { margin-bottom: 8px; }
  .popup-facts { font-size: 12.5px; color: var(--muted); margin: 6px 0; }
  .popup-facts b { color: var(--ink); }
  .popup-haz { border-left: 3px solid #d9822b; background: rgba(217,130,43,.1);
               padding: 6px 9px; border-radius: 0 8px 8px 0; font-size: 12.5px; margin: 8px 0; }
  .popup-fun { font-size: 12.5px; margin: 4px 0 4px 0; padding-left: 16px; }
  .popup-src { font-size: 11px; color: var(--muted); margin-top: 8px; }
  .popup-chip { display: inline-block; font-size: 10.5px; font-weight: 700; padding: 2px 8px;
                border-radius: 999px; color: #fff; margin-bottom: 6px; margin-right: 4px; }

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
      <a class="cta" href="#explore">Explore the chart</a>
      <a class="cta ghost" href="https://github.com/rotblauer/Anchor">View on GitHub</a>
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
      <div class="card"><span class="emoji">🗓️</span><h3>Multi-night stays</h3>
        <p>Pick 1–7 nights and every place is ranked across the whole window, worst night weighted heaviest — plus live buoy reality checks and a wave layer.</p></div>
    </div>
  </section>

  <section id="explore">
    <h2>Explore every anchorage, dock &amp; legend</h2>
    <p class="lede">The app's complete catalog on one chart — $SITE_COUNT documented places and lore sites, straight from the same database the app ships with. Tap any pin for the full story. (Live wind, waves, and night-by-night ratings live in the app.)</p>
    <div class="map-controls">
      <input id="mapsearch" type="search" placeholder="Search bays, wrecks, lighthouses…" aria-label="Search map sites">
      <span id="mapcount" class="map-note" style="margin:0"></span>
    </div>
    <div class="map-controls" id="mapchips"></div>
    <div id="map" aria-label="Interactive map of Apostle Islands anchorages, docks, marinas, and points of interest"></div>
    <p class="map-note">Circles are places to stay (anchorages, docks, marinas); diamonds are lore — lighthouses, shipwrecks, sea caves, historic sites, and natural wonders. Purple means an advisory or closure. Imagery © Esri.</p>
  </section>

  <section>
    <h2>Plan, browse, explore — in the app</h2>
    <p class="lede">A live wind-field map with a play-through time scrubber, ranked picks for any stay length, protection roses on every anchorage, live NDBC buoy comparisons, marine alerts from NOAA — plus all the island stories for the days you're not going anywhere.</p>
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
        <li><strong>Waves:</strong> Open-Meteo Marine wave height, direction, and period — a wave-field map layer plus per-place charts, labeled honestly as open-water values.</li>
        <li><strong>Live stations:</strong> NDBC/GLOS observations (Devils Island, Port Wing, Saxon Harbor) shown against what the forecast claimed, delta and all.</li>
        <li><strong>Marine alerts:</strong> Live Small Craft Advisories and Gale Warnings from NOAA/NWS for the five nearshore zones around the islands.</li>
        <li><strong>Places:</strong> Every entry cites its sources in-app and on this page. $ADVISORY_COUNT advisory entries flag wildlife closures and day-use-only areas.</li>
        <li><strong>Lore:</strong> $LORE_BREAKDOWN — every story fact-checked and sourced, browsable on the map above and in the app.</li>
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

<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"></script>
<script>
$EXPLORE_DATA

(function () {
  var GLYPHS = {
    anchorage: '<svg viewBox="0 0 24 24"><circle cx="12" cy="5" r="2.2"/><line x1="12" y1="7.2" x2="12" y2="20"/><line x1="7" y1="10.5" x2="17" y2="10.5"/><path d="M4.5 14.5 C5.5 18.5 9 20.5 12 20.5 C15 20.5 18.5 18.5 19.5 14.5"/></svg>',
    dock: '<svg viewBox="0 0 24 24"><line x1="4" y1="9" x2="20" y2="9"/><line x1="7" y1="9" x2="7" y2="19"/><line x1="12" y1="9" x2="12" y2="19"/><line x1="17" y1="9" x2="17" y2="19"/></svg>',
    marina: '<svg viewBox="0 0 24 24"><rect x="5.5" y="5" width="8" height="14" rx="1.5"/><line x1="7.5" y1="8.5" x2="11.5" y2="8.5"/><path d="M13.5 11h2l2 2v4.2a1.6 1.6 0 0 1-3.2 0"/></svg>',
    advisory: '<svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="14"/><line x1="12" y1="18" x2="12" y2="18.01"/></svg>',
    lighthouse: '<svg viewBox="0 0 24 24"><path d="M10 20 L11 6 h2 L14 20 Z"/><line x1="7.5" y1="20" x2="16.5" y2="20"/><line x1="12" y1="6" x2="12" y2="4"/><line x1="6" y1="5.5" x2="8.5" y2="7"/><line x1="18" y1="5.5" x2="15.5" y2="7"/></svg>',
    shipwreck: '<svg viewBox="0 0 24 24"><path d="M4 15 q4 3 8 0 t8 0"/><line x1="8" y1="14" x2="16" y2="7"/><line x1="16" y1="7" x2="16" y2="12"/></svg>',
    sea_cave: '<svg viewBox="0 0 24 24"><path d="M4 10 q2.5 -2.8 5 0 t5 0 t5 0"/><path d="M4 15.5 q2.5 -2.8 5 0 t5 0 t5 0"/></svg>',
    historic: '<svg viewBox="0 0 24 24"><line x1="4" y1="19.5" x2="20" y2="19.5"/><line x1="6.5" y1="10" x2="6.5" y2="19.5"/><line x1="12" y1="10" x2="12" y2="19.5"/><line x1="17.5" y1="10" x2="17.5" y2="19.5"/><path d="M4 10 L12 4.5 L20 10 Z"/></svg>',
    natural: '<svg viewBox="0 0 24 24"><path d="M12 4 C7 9 7 14 12 20 C17 14 17 9 12 4 Z"/><line x1="12" y1="9.5" x2="12" y2="20"/></svg>'
  };
  var CATS = {
    anchorage: { color: '#128fa3', label: 'Anchorages', shape: 'circle', glyph: 'anchorage' },
    dock: { color: '#0b6e7f', label: 'Docks', shape: 'circle', glyph: 'dock' },
    marina: { color: '#3a8f5d', label: 'Marinas', shape: 'circle', glyph: 'marina' },
    lighthouse: { color: '#d9a521', label: 'Lighthouses', shape: 'diamond', glyph: 'lighthouse' },
    shipwreck: { color: '#a0522d', label: 'Shipwrecks', shape: 'diamond', glyph: 'shipwreck' },
    sea_cave: { color: '#2691bf', label: 'Sea caves', shape: 'diamond', glyph: 'sea_cave' },
    historic: { color: '#8c61a8', label: 'Historic', shape: 'diamond', glyph: 'historic' },
    natural: { color: '#389a59', label: 'Natural', shape: 'diamond', glyph: 'natural' }
  };
  var ADVISORY_COLOR = '#855aa0';

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function srcLinks(list) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var s = list[i];
      if (/^https?:/.test(s)) {
        var label = s;
        try { label = new URL(s).hostname.replace('www.', ''); } catch (e) {}
        out.push('<a href="' + esc(s) + '" target="_blank" rel="noopener">' + esc(label) + '</a>');
      } else {
        out.push(esc(s));
      }
    }
    return out.join(' · ');
  }
  function paras(text) {
    var parts = String(text || '').split(/\n\n+/);
    var out = '';
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].trim()) out += '<p>' + esc(parts[i].trim()) + '</p>';
    }
    return out;
  }
  function funList(facts) {
    if (!facts || !facts.length) return '';
    var out = '<ul>';
    for (var i = 0; i < facts.length; i++) out += '<li class="popup-fun">' + esc(facts[i]) + '</li>';
    return out + '</ul>';
  }

  function placeCat(p) {
    if (p.t === 'anchorage_dock') return 'anchorage';
    return p.t;
  }
  function placePopup(p) {
    var cat = CATS[placeCat(p)];
    var typeLabel = p.t === 'anchorage_dock' ? 'Anchorage + Dock' : cat.label.replace(/s$$/, '');
    var out = '<div class="popup-body">';
    out += '<span class="popup-chip" style="background:' + (p.adv ? ADVISORY_COLOR : cat.color) + '">' + esc(typeLabel) + '</span>';
    if (p.adv) out += '<span class="popup-chip" style="background:' + ADVISORY_COLOR + '">Advisory — not an overnight stop</span>';
    out += '<h3>' + esc(p.n) + '</h3><div class="popup-island">' + esc(p.i) + '</div>';
    if (p.best) out += '<div class="popup-tag" style="color:' + cat.color + '">' + esc(p.best) + '</div>';
    out += '<p>' + esc(p.d) + '</p>';
    var facts = [];
    if (p.depth) facts.push('<b>Depth:</b> ' + esc(p.depth));
    if (p.bottom && p.bottom !== 'Unknown') facts.push('<b>Bottom:</b> ' + esc(p.bottom));
    if (p.holding && p.holding !== 'Unknown') facts.push('<b>Holding:</b> ' + esc(p.holding));
    if (facts.length) out += '<div class="popup-facts">' + facts.join(' · ') + '</div>';
    if (p.dock) out += '<div class="popup-facts"><b>Dock:</b> ' + esc(p.dock) + '</div>';
    if (p.amen && p.amen.length) out += '<div class="popup-facts"><b>Amenities:</b> ' + esc(p.amen.join(', ')) + '</div>';
    if (p.haz) out += '<div class="popup-haz">' + esc(p.haz) + '</div>';
    out += funList(p.facts);
    if (p.src && p.src.length) out += '<div class="popup-src">' + srcLinks(p.src) + '</div>';
    return out + '</div>';
  }
  function poiPopup(p) {
    var cat = CATS[p.k];
    var out = '<div class="popup-body">';
    out += '<span class="popup-chip" style="background:' + cat.color + '">' + esc(cat.label.replace(/s$$/, '')) + '</span>';
    out += '<h3>' + esc(p.n) + '</h3><div class="popup-island">' + esc(p.i) + '</div>';
    if (p.tag) out += '<div class="popup-tag" style="color:' + cat.color + '">' + esc(p.tag) + '</div>';
    out += paras(p.story);
    if (p.tips) out += '<div class="popup-facts"><b>Visiting:</b> ' + esc(p.tips) + '</div>';
    out += funList(p.facts);
    if (p.src && p.src.length) out += '<div class="popup-src">' + srcLinks(p.src) + '</div>';
    return out + '</div>';
  }

  function icon(catKey, advisory) {
    var cat = CATS[catKey];
    var color = advisory ? ADVISORY_COLOR : cat.color;
    var glyph = GLYPHS[advisory ? 'advisory' : cat.glyph];
    var inner = cat.shape === 'diamond'
      ? '<div class="pin pin-diamond" style="background:' + color + '"><div class="pin-glyph">' + glyph + '</div></div>'
      : '<div class="pin pin-circle" style="background:' + color + '">' + glyph + '</div>';
    return L.divIcon({ className: '', html: inner, iconSize: [22, 22], iconAnchor: [11, 11], popupAnchor: [0, -10] });
  }

  var map = L.map('map', { scrollWheelZoom: false });
  map.setView([46.93, -90.68], 10);
  L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
    attribution: 'Imagery &copy; Esri &amp; contributors', maxZoom: 17
  }).addTo(map);
  map.on('click focus', function () { map.scrollWheelZoom.enable(); });
  map.on('mouseout', function () { map.scrollWheelZoom.disable(); });

  var cluster = L.markerClusterGroup({ maxClusterRadius: 32, showCoverageOnHover: false });
  map.addLayer(cluster);

  var all = [];
  var i;
  for (i = 0; i < PLACES.length; i++) {
    var p = PLACES[i];
    var catKey = placeCat(p);
    all.push({
      cat: catKey,
      text: (p.n + ' ' + p.i + ' ' + (p.best || '')).toLowerCase(),
      marker: L.marker([p.lat, p.lon], { icon: icon(catKey, p.adv), title: p.n, alt: p.n })
        .bindPopup(placePopup(p), { maxWidth: 330 })
    });
  }
  for (i = 0; i < POIS.length; i++) {
    var q = POIS[i];
    all.push({
      cat: q.k,
      text: (q.n + ' ' + q.i + ' ' + (q.tag || '')).toLowerCase(),
      marker: L.marker([q.lat, q.lon], { icon: icon(q.k, false), title: q.n, alt: q.n })
        .bindPopup(poiPopup(q), { maxWidth: 330 })
    });
  }

  var active = {};
  var key;
  for (key in CATS) active[key] = true;
  var query = '';

  function render() {
    cluster.clearLayers();
    var shown = 0;
    for (var j = 0; j < all.length; j++) {
      var item = all[j];
      if (!active[item.cat]) continue;
      if (query && item.text.indexOf(query) === -1) continue;
      cluster.addLayer(item.marker);
      shown++;
    }
    document.getElementById('mapcount').textContent = 'Showing ' + shown + ' of ' + all.length + ' sites';
  }

  var chipBar = document.getElementById('mapchips');
  function addChip(label, catKey) {
    var b = document.createElement('button');
    b.className = 'fchip on';
    b.textContent = label;
    b.setAttribute('aria-pressed', 'true');
    function paint() {
      var on = catKey === null || active[catKey];
      if (catKey === null) {
        on = true;
        for (var k in CATS) { if (!active[k]) on = false; }
      }
      b.className = on ? 'fchip on' : 'fchip';
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
      if (on) b.style.background = catKey === null ? '#128fa3' : CATS[catKey].color;
      else b.style.background = '';
    }
    b.onclick = function () {
      if (catKey === null) {
        for (var k in CATS) active[k] = true;
      } else {
        active[catKey] = !active[catKey];
      }
      var buttons = chipBar.querySelectorAll('button');
      for (var x = 0; x < buttons.length; x++) buttons[x].dispatchEvent(new Event('paint'));
      render();
    };
    b.addEventListener('paint', paint);
    paint();
    chipBar.appendChild(b);
  }
  addChip('All', null);
  for (key in CATS) addChip(CATS[key].label, key);

  var search = document.getElementById('mapsearch');
  search.addEventListener('input', function () {
    query = search.value.trim().toLowerCase();
    render();
  });

  render();
})();
</script>

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
    SITE_COUNT=str(len(PLACES) + len(POIS)),
    EXPLORE_DATA=explore_data,
    GENERATED=generated,
))
print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes) — {len(PLACES)} places, {len(POIS)} POIs, {len(CONTENT['islands'])} islands")
