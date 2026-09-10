# Rice overhaul — verified design reference

Generated from a 14-agent design + adversarial-verification pass (7 domain designers, 7 independent
verifiers). 104 proposals, 135 verdicts: 89 confirmed, 34 refuted, 12 uncertain. Every option name
was checked against the Noctalia 5.0.1 source tree, the Stylix source tree, Hyprland 0.56.2's
shipped Lua API stub (`share/hypr/stubs/hl.meta.lua`), and live `hyprctl` /
`noctalia config export full` output.

**Read the verdict on a change before implementing it.** `WRONG` means the verifier refuted the
proposal and supplied a correction. `UNCERTAIN` means it could not be proven and needs a live check.
All snippets are FRAGMENTS — merge them into the existing attrsets, never paste beside them.

## Domains

- [Colour architecture](color.md) — 11 changes; 10 confirmed, 4 refuted, 4 uncertain (80K)
- [Compositor feel](motion.md) — 14 changes; 13 confirmed, 3 refuted, 1 uncertain (77K)
- [Noctalia bar and chrome](bar.md) — 10 changes; 15 confirmed, 5 refuted, 3 uncertain (72K)
- [Typography, icons, Qt/GTK](type.md) — 13 changes; 9 confirmed, 7 refuted, 2 uncertain (80K)
- [Correctness and dead config](hygiene.md) — 19 changes; 15 confirmed, 4 refuted, 2 uncertain (79K)
- [Interaction](ux.md) — 23 changes; 17 confirmed, 7 refuted, 0 uncertain (90K)
- [Lock, session, startup](session.md) — 14 changes; 10 confirmed, 4 refuted, 0 uncertain (76K)
