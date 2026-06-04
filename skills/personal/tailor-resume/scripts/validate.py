#!/usr/bin/env python3
"""Structural validator for tailor-resume output.

Usage: validate.py <master.json> <tailored.json>

Enforces the tailor-resume contract: the tailored file must be the SAME Reactive
Resume document with only a small editable surface changed. Everything else must be
byte-identical to the master. Exits 0 (PASS) or 1 (FAIL, with a list of violations).

Editable surface (the ONLY things allowed to differ from master):
  - basics.headline                              (free text)
  - summary.content                              (HTML prose)
  - sections.experience.items[].description      (HTML bullets; >=1 <li> required)
  - sections.skills.items[].keywords             (reorder/drop only; must be a subset)

Everything else is frozen. No item may be added or removed from any section.
"""

import json
import re
import sys


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def without(d, *keys):
    """Shallow copy of dict d with the named keys removed."""
    return {k: v for k, v in d.items() if k not in keys}


def main():
    if len(sys.argv) != 3:
        print("usage: validate.py <master.json> <tailored.json>", file=sys.stderr)
        return 2

    master_path, out_path = sys.argv[1], sys.argv[2]

    try:
        master = load(master_path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"FAIL: cannot read master: {e}", file=sys.stderr)
        return 1
    try:
        out = load(out_path)
    except json.JSONDecodeError as e:
        print(f"FAIL: tailored file is not valid JSON: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"FAIL: cannot read tailored file: {e}", file=sys.stderr)
        return 1

    v = []  # violations

    # ---- top-level keys identical ----
    if set(master.keys()) != set(out.keys()):
        added = set(out) - set(master)
        removed = set(master) - set(out)
        if added:
            v.append(f"top-level keys added: {sorted(added)}")
        if removed:
            v.append(f"top-level keys removed: {sorted(removed)}")

    # ---- frozen top-level blocks: byte-identical ----
    for key in ("picture", "metadata", "customSections"):
        if master.get(key) != out.get(key):
            v.append(f"frozen top-level block '{key}' was modified")

    # ---- basics: everything except headline frozen ----
    if without(master.get("basics", {}), "headline") != without(out.get("basics", {}), "headline"):
        v.append("basics changed outside of 'headline'")
    if "headline" not in out.get("basics", {}):
        v.append("basics.headline is missing")

    # ---- summary: everything except content frozen ----
    if without(master.get("summary", {}), "content") != without(out.get("summary", {}), "content"):
        v.append("summary changed outside of 'content'")

    # ---- sections ----
    m_sections = master.get("sections", {})
    o_sections = out.get("sections", {})
    if set(m_sections.keys()) != set(o_sections.keys()):
        v.append("sections set changed (a whole section was added/removed)")

    # per-item editable fields; any section not listed here is fully frozen
    editable_item_fields = {"experience": {"description"}, "skills": {"keywords"}}

    for name in m_sections.keys() & o_sections.keys():
        ms, os_ = m_sections[name], o_sections[name]

        # section-level metadata (title/icon/columns/hidden) frozen
        if without(ms, "items") != without(os_, "items"):
            v.append(f"section '{name}' metadata (title/icon/columns/hidden) changed")

        m_items = ms.get("items", [])
        o_items = os_.get("items", [])

        # same ids, same order, no add/remove
        m_ids = [it.get("id") for it in m_items]
        o_ids = [it.get("id") for it in o_items]
        if m_ids != o_ids:
            v.append(f"section '{name}': item ids/order changed "
                     f"(items added, removed, or reordered)")
            continue  # can't reliably field-compare misaligned items

        editable = editable_item_fields.get(name, set())
        for m_it, o_it in zip(m_items, o_items):
            iid = m_it.get("id", "?")

            # all non-editable fields frozen
            if without(m_it, *editable) != without(o_it, *editable):
                v.append(f"section '{name}' item {iid}: frozen field changed")

            # experience: bullet floor of 1, HTML preserved
            if name == "experience":
                desc = o_it.get("description", "")
                if len(re.findall(r"<li", desc)) < 1:
                    v.append(f"experience item {iid}: fewer than 1 bullet (<li>)")

            # skills: keywords must be a subset of master (no invented terms), non-empty
            if name == "skills":
                m_kw = set(m_it.get("keywords", []))
                o_kw = o_it.get("keywords", [])
                invented = set(o_kw) - m_kw
                if invented:
                    v.append(f"skills group {iid}: invented keyword(s) {sorted(invented)}")
                if m_it.get("keywords") and not o_kw:
                    v.append(f"skills group {iid}: keywords emptied")

    if v:
        print("FAIL: tailored resume violates the contract:")
        for item in v:
            print(f"  - {item}")
        return 1

    print("PASS: tailored resume is structurally sound (only the editable surface differs).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
