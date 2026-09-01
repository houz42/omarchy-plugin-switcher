# omarchy-plugin-switcher

An [Omarchy](https://omarchy.org/) shell plugin that gives you a Vimium-style
hint mode for the bar: open it, a small letter/number badge appears next to
every plugin icon, press that key, and that plugin's panel toggles open or
closed immediately -- no typing a name, no Enter, no per-plugin hotkey.

![Plugin Switcher hint mode](screenshots/menu.png)

It's a fully standalone plugin -- it doesn't touch, clone, or replace any
other plugin. Install it and a new icon shows up next to the existing ones.

## Install

```sh
omarchy plugin add https://github.com/houz42/omarchy-plugin-switcher.git --enable
```

## Use

- Click the bar icon, or run `omarchy-shell shell toggle houz42.plugin-switcher`.
- A badge appears next to every visible plugin icon on the bar. Press the
  key shown on a badge to toggle that plugin's panel -- one keystroke, no
  Enter. Press Escape, or click anywhere outside a badge, to cancel.

## Keybinding (Hyprland / Omarchy)

`SUPER + ALT + P` is added automatically, the first time the plugin ever
loads, by appending this line to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + P", "Plugin Switcher", "omarchy-shell shell toggle houz42.plugin-switcher")
```

Omarchy's plugin system has no keybinding field of its own to declare this
in `manifest.json` -- the only way to get a default binding is a plugin
editing `bindings.lua` itself, so that's what this one does, once, marked
with a comment (`-- Added by omarchy-plugin-switcher on first load`) so
it's obvious where it came from.

**To use a different key**, edit or delete that line directly -- it's a
plain line in your own `bindings.lua` like any other binding, and won't be
re-added once you've touched it (the plugin only checks whether *a* line
mentioning `houz42.plugin-switcher` exists at all, not what key it's bound
to). If you track `bindings.lua` with a dotfile manager (chezmoi, stow,
...), this appended line lives only in the live file until you re-add it
to your dotfile source, same as any other manual edit to that file.

## How it works

Badge positions come from `bar.debugBarGeometry()`, the same first-party
function the bar's own overlay-click forwarding relies on -- it returns
every bar module's id and on-screen position. Each visible icon gets a
badge labeled from a key pool (digits first, then lowercase a-z, then
uppercase A-Z), skipping `h`/`j`/`k`/`l`/`x` since those are reserved for
cursor movement and delete elsewhere in Omarchy's own panel key handling.
Pressing a badge's key runs `omarchy-shell shell toggle <id>` for that
plugin -- the same call its own bar icon's click makes.

Coordinates line up directly with screen coordinates for a full-width top
bar; bottom/left/right bar positions aren't handled yet.

## Known limitations

- Badge positions assume a full-width **top** bar; other bar positions
  aren't handled.
- A handful of bar widgets have no popup of their own (a decorative
  spacer, the workspace-number indicator) and are skipped -- toggling them
  would be a silent no-op. There's no way to detect that generically, so
  known no-op ids are denylisted in `Panel.qml`.
- The label pool has 56 keys (10 digits + lowercase a-z + uppercase A-Z,
  minus the 5 reserved letters). On a bar with more than 56 visible
  plugin icons, the excess ones (sorted left to right) get no badge.
- Uses Omarchy's internal shell components (`qs.Ui` / `qs.Commons` /
  `bar.debugBarGeometry()`), which aren't a documented stable plugin API
  and could change without notice.

## Removal

```bash
omarchy plugin remove houz42.plugin-switcher
```

This removes the plugin itself but, since it lives outside the plugin's
own directory, does **not** touch the keybinding line it added to
`~/.config/hypr/bindings.lua` on first load -- delete that line yourself
if you want it gone too.

## License

MIT
