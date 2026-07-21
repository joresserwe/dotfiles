#!/usr/bin/env python3
"""Inject the dotfiles-managed profile and color schemes into a live Windows
Terminal settings.json, replacing prior copies by guid/name. Everything else
in the file (user-managed profiles, global settings) is left untouched."""
import json
import sys

settings_path, fragment_path = sys.argv[1], sys.argv[2]

with open(fragment_path, encoding="utf-8") as f:
    frag = json.load(f)
with open(settings_path, encoding="utf-8") as f:
    settings = json.load(f)

profiles = settings.setdefault("profiles", {}).setdefault("list", [])
profile = frag["profile"]
profiles[:] = [p for p in profiles if p.get("guid") != profile["guid"]]
profiles.append(profile)

if "defaults" in frag:
    settings["profiles"].setdefault("defaults", {}).update(frag["defaults"])

schemes = settings.setdefault("schemes", [])

frag_scheme_names = {s["name"] for s in frag["schemes"]}
schemes[:] = [s for s in schemes if s.get("name") not in frag_scheme_names]

schemes.extend(frag["schemes"])

actions = settings.setdefault("actions", [])
frag_keys = {a["keys"] for a in frag.get("actions", [])}
actions[:] = [a for a in actions if a.get("keys") not in frag_keys]
actions.extend(frag.get("actions", []))

# WT normalizes legacy actions on load: commands move to "actions" (id only)
# and the keys land in a separate "keybindings" list — scrub ours there too
# or every re-run stacks a duplicate binding.
keybindings = settings.get("keybindings")
if isinstance(keybindings, list):
    keybindings[:] = [k for k in keybindings if k.get("keys") not in frag_keys]

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
scheme_names = ", ".join(s["name"] for s in frag["schemes"])
print(f"applied profile '{profile['name']}' and schemes: {scheme_names}")
