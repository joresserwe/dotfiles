#!/usr/bin/env python3
"""Merge a dotfiles-managed fragment into a live Windows Terminal
settings.json. Fragment sections are all optional: "profile" and "schemes"
replace prior copies by guid/name, "defaults" and "globals" update in place.
Anything the fragment doesn't name is left untouched."""
import json
import sys

settings_path, fragment_path = sys.argv[1], sys.argv[2]

with open(fragment_path, encoding="utf-8") as f:
    frag = json.load(f)
with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

applied = []

if "profile" in frag:
    profiles = settings.setdefault("profiles", {}).setdefault("list", [])
    profile = frag["profile"]
    profiles[:] = [p for p in profiles if p.get("guid") != profile["guid"]]
    profiles.append(profile)
    applied.append(f"profile '{profile['name']}'")

if "defaults" in frag:
    settings.setdefault("profiles", {}).setdefault("defaults", {}).update(frag["defaults"])
    applied.append("profile defaults")

if "schemes" in frag:
    schemes = settings.setdefault("schemes", [])
    frag_scheme_names = {s["name"] for s in frag["schemes"]}
    schemes[:] = [s for s in schemes if s.get("name") not in frag_scheme_names]
    schemes.extend(frag["schemes"])
    applied.append("schemes: " + ", ".join(frag_scheme_names))

if "actions" in frag:
    actions = settings.setdefault("actions", [])
    frag_keys = {a["keys"] for a in frag["actions"]}
    actions[:] = [a for a in actions if a.get("keys") not in frag_keys]
    actions.extend(frag["actions"])

    # WT normalizes legacy actions on load: commands move to "actions" (id only)
    # and the keys land in a separate "keybindings" list — scrub ours there too
    # or every re-run stacks a duplicate binding.
    keybindings = settings.get("keybindings")
    if isinstance(keybindings, list):
        keybindings[:] = [k for k in keybindings if k.get("keys") not in frag_keys]

if "globals" in frag:
    settings.update(frag["globals"])
    applied.append("globals: " + ", ".join(frag["globals"]))

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
print("applied " + "; ".join(applied))
