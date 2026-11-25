# swiftbar-m2-load

A [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that shows the load of another Mac in the menu bar, the way the "mini" widgets of [Stats](https://github.com/exelban/stats) show the load of this one — a small caption over each value:

```
M2 CPU  M2 RAM
 23%     75%
```

CPU is usage (user + system), RAM is memory used. Both are fetched over ssh every 15 seconds.

The dropdown has the details:

- CPU split into user and system, load average and the number of cores;
- memory used of total, memory pressure (orange on warning, red on critical), swap used of total;
- the number of running `claude` processes (Claude Code sessions);
- the five processes using the most CPU and the five using the most memory.

When the Mac cannot be reached (asleep, off the network, ssh refused), the values turn into a grey `—` and the dropdown says why and when the Mac was last seen.

## How the numbers are taken

One `ssh` call per refresh runs `top`, `vm_stat`, `sysctl` and `ps` on the other Mac; nothing is installed there.

- CPU is the second sample of `top -l 2 -s 1`, so it is the usage over the last second, like Stats.
- Memory used is counted the way Stats counts it, so the numbers match: active + inactive + speculative + wired + compressed − purgeable − file-backed pages, out of `hw.memsize`.
- Top CPU comes from the same `top` sample (its own `top` process is left out); process names come from `ps`.
- Top memory is by resident size from `ps`.

## How the title is drawn

SwiftBar titles are one line, so the two-line title is an image: `osascript` runs `lib/m2_load/widget.js`, which draws the text with AppKit in the system font, with the sizes of Stats' mini widget. The image is a template, so macOS colours it for a light or dark menu bar. Each block is at least as wide as `100%`, so the item does not jump as values change. If drawing fails, the title falls back to text: `M2 23% · 75%`, or a grey `M2 —`.

## Install

Requires macOS with SwiftBar on this Mac and Remote Login (ssh) on the other one. The plugin runs on the system `/usr/bin/ruby` with the standard library only.

1. Make `ssh m2` work without a password prompt: an `m2` host in `~/.ssh/config` and a key the other Mac accepts. The plugin runs ssh with `BatchMode=yes`, so it never asks for anything.
2. Link the plugin into the SwiftBar plugin folder:

   ```sh
   git clone https://github.com/marat-y/swiftbar-m2-load.git
   ln -s "$PWD/swiftbar-m2-load/m2-load.15s.rb" "$HOME/Library/Application Support/SwiftBar/Plugins/m2-load.15s.rb"
   ```

   The `15s` in the link name is the refresh interval; rename the link to change it.
3. If the other Mac is on the local network and the dropdown says `No route to host` while `ssh m2` works in Terminal, allow SwiftBar in **System Settings → Privacy & Security → Local Network**.

## Settings

Two environment variables change the Mac and the label:

| Variable | Default | Meaning |
| --- | --- | --- |
| `M2_LOAD_HOST` | `m2` | ssh host (an alias from `~/.ssh/config` or `user@host`). |
| `M2_LOAD_LABEL` | `M2` | Prefix of the captions (`M2 CPU`, `M2 RAM`). |

SwiftBar has no place to set them, so put a small wrapper into the plugin folder instead of the link, for example `studio-load.15s.sh`:

```sh
#!/bin/sh
M2_LOAD_HOST=studio M2_LOAD_LABEL=S exec "$HOME/swiftbar-m2-load/m2-load.15s.rb"
```

Make it executable; several wrappers show several Macs. The time a Mac was last seen is kept in `last_seen` in SwiftBar's data folder of each plugin.

## Development

```sh
/usr/bin/ruby -S rake test
```
