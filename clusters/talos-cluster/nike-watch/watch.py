import json
import os
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone

MIMIR_URL = os.environ.get("MIMIR_URL", "http://mimir-service.mimir.svc.cluster.local:3000")
HERMES_URL = os.environ.get("HERMES_URL", "http://hermes-service.hermes.svc.cluster.local")
STATE_PATH = os.environ.get("STATE_PATH", "/data/state.json")
DRY_RUN = os.environ.get("DRY_RUN") == "1"
FAIL_LIMIT = 3
FINAL_REMINDER_SECONDS = 24 * 3600

SOURCES = {
    "soleretriever": "https://soleretriever.com/sneaker-release-dates/nike/other/nike-24-7-recovery-boot-dark-driftwood-ir0450-200",
    "sneaktorious": "https://sneaktorious.com/nike-24-7-recovery-boot-dark-driftwood-ir0450-200-release-info",
    "sneakerjagers_eu": "https://sneakerjagers.com/en/n/nike-24-7-recovery-boot-dark-driftwood/8037",
    "nike_fr": "https://www.nike.com/fr/w?q=24.7%20boot",
}
LIVE_RE = re.compile(r"\b(available now|out now|in stock|shop now|buy now|disponible|en stock|live now)\b", re.I)


def extract(url):
    body = json.dumps({"url": url, "options": {"timeout_seconds": 80}}).encode()
    req = urllib.request.Request(MIMIR_URL + "/v1/extract", data=body, headers={
        "Authorization": "Bearer " + os.environ["MIMIR_KEY"], "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=110) as r:
        d = json.load(r)
    md = d.get("markdown") or ""
    if d.get("status") == "blocked" or len(md) < 200:
        raise RuntimeError(f"extraction {d.get('status')} ({len(md)} chars)")
    return md


def first(pattern, text, default="?"):
    m = re.search(pattern, text, re.I)
    return re.sub(r"\s+", " ", m.group(1)).strip(" .*") if m else default


def parse_soleretriever(md):
    return {
        "release": first(r"will be released (.+?)(?=,? (?:through|via|at|on Nike)\b|\.|\n|\s{2,}|$)", md),
        "price": first(r"retail price is set at ([$€£]\s?\d[\d.,]*)", md),
        "live_hint": bool(LIVE_RE.search(md)),
    }


def parse_sneaktorious(md):
    return {
        "release": first(r"Release Date:\**\s*([^*\n]+)", md),
        "price": first(r"Retail Price:\**\s*([^*\n]+)", md),
        "where": first(r"Where to Buy:\**\s*([^*\n]+)", md),
        "live_hint": bool(LIVE_RE.search(md)),
    }


def parse_sneakerjagers(md):
    section = first(r"## Release and price\s+(.{0,400})", md, "")
    unconfirmed = "not been confirmed" in section
    return {
        "eu_confirmed": not unconfirmed,
        "eu_date": "unconfirmed" if unconfirmed else first(r"(\d{1,2} \w+ 2026|\w+ \d{1,2},? 2026)", section),
        "eu_price": "unconfirmed" if unconfirmed else first(r"(€\s?\d[\d.,]*|\d[\d.,]*\s?€)", section),
    }


def parse_nike_fr(md):
    items = []
    for line in md.splitlines():
        if "24.7" in line and re.search(r"\b(boot|botte|bottine|IR0450)", line, re.I):
            items.append(re.sub(r"\s+", " ", line.strip("- ")).strip()[:160])
    return {"boot_listed": bool(items), "listings": sorted(set(items))}


PARSERS = {
    "soleretriever": parse_soleretriever,
    "sneaktorious": parse_sneaktorious,
    "sneakerjagers_eu": parse_sneakerjagers,
    "nike_fr": parse_nike_fr,
}


def load_state():
    try:
        with open(STATE_PATH) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"facts": {}, "fails": {}, "broken_notified": [], "live_at": None, "done": False}


def save_state(st):
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(st, f, indent=2)
    os.replace(tmp, STATE_PATH)


def send(subject, body):
    if DRY_RUN:
        print(f"--- EMAIL (dry run) ---\nSubject: {subject}\n\n{body}\n-----------------------")
        return
    payload = json.dumps({"account_id": os.environ["HERMES_ACCOUNT"], "to": os.environ["NOTIFY_TO"],
                          "subject": subject, "body": body}).encode()
    req = urllib.request.Request(HERMES_URL + "/emails/send", data=payload, headers={
        "Authorization": "Bearer " + os.environ["HERMES_KEY"], "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        print("email sent:", r.status, subject)


def describe(facts):
    lines = []
    for name, f in facts.items():
        lines.append(f"{name}: " + ", ".join(f"{k}={v}" for k, v in f.items()))
    return "\n".join(lines)


def main():
    st = load_state()
    if st.get("done"):
        print("watcher finished; nothing to do")
        return
    now = time.time()
    if st.get("live_at") and now - st["live_at"] >= FINAL_REMINDER_SECONDS:
        send("REMINDER: Nike 24.7 Recovery Boot is live, did you buy it?",
             "The boot went live 24h ago. Links:\n" + "\n".join(SOURCES.values()) +
             "\n\nThis is the last email from the watcher.")
        st["done"] = True
        save_state(st)
        return

    first_run = not st["facts"]
    new_facts, changes, broken = {}, [], []
    for name, url in SOURCES.items():
        try:
            new_facts[name] = PARSERS[name](extract(url))
            st["fails"][name] = 0
            if name in st["broken_notified"]:
                st["broken_notified"].remove(name)
        except Exception as e:
            st["fails"][name] = st["fails"].get(name, 0) + 1
            print(f"{name} failed ({st['fails'][name]}x): {type(e).__name__}: {e}", file=sys.stderr)
            if name in st["facts"]:
                new_facts[name] = st["facts"][name]
            if st["fails"][name] >= FAIL_LIMIT and name not in st["broken_notified"]:
                broken.append(f"{name} ({url}): {type(e).__name__}: {e}")
                st["broken_notified"].append(name)
            continue
        old = st["facts"].get(name, {})
        for k, v in new_facts[name].items():
            if not first_run and old.get(k) != v:
                changes.append(f"{name} {k}: {old.get(k)!r} -> {v!r}")

    live = new_facts.get("nike_fr", {}).get("boot_listed") or any(
        f.get("live_hint") for f in new_facts.values()) or new_facts.get("sneakerjagers_eu", {}).get("eu_confirmed")
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    links = "\n".join(f"- {n}: {u}" for n, u in SOURCES.items())

    if first_run:
        print(f"baseline recorded {stamp}:\n{describe(new_facts)}")
    elif live and not st.get("live_at"):
        st["live_at"] = now
        send("IT'S LIVE: Nike 24.7 Recovery Boot (IR0450-200)",
             f"Something indicates the boot is available or EU-confirmed ({stamp}).\n\nChanges:\n" +
             ("\n".join(changes) or "(first live signal)") + f"\n\nCurrent:\n{describe(new_facts)}\n\nBuy / check:\n{links}")
    elif changes:
        send("Nike boot update: " + changes[0][:80],
             f"Changes detected {stamp}:\n" + "\n".join(changes) + f"\n\nCurrent:\n{describe(new_facts)}\n\nSources:\n{links}")
    else:
        print("no changes")

    if broken:
        send("Nike boot watcher: source broken",
             "These sources failed 3 runs in a row; the watcher may miss updates:\n" + "\n".join(broken))

    st["facts"] = new_facts
    save_state(st)


if __name__ == "__main__":
    main()
