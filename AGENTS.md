# swiftbar-m2-load

SwiftBar plugin: CPU and memory load of the MacBook M2 (ssh alias `m2`) in the menu bar of this Mac. What it shows and how it works — `README.md`.

- SwiftBar runs the plugin with `/usr/bin/ruby` 2.6, not a version manager's Ruby. Keep the code 2.6-compatible and stdlib-only: no `filter_map`, `Hash#except`, `=>` pattern matching, gems. Run the tests with the system Ruby, `PATH=/usr/bin:/bin /usr/bin/ruby -S rake test` (the mise `rake` shim breaks it otherwise), and with one current Ruby, e.g. `mise exec ruby@latest -- rake test`.
- The repo is private but kept ready to publish: everything in it is in English, nothing personal beyond the default host alias.
- Memory used must match Stats (see `README.md`); change the formula only together with Stats.

## After changes

- The plugin is linked into SwiftBar: `~/Library/Application Support/SwiftBar/Plugins/m2-load.15s.rb` → `m2-load.15s.rb` in the repo, so code edits take effect at the next refresh. To refresh at once: `open -g "swiftbar://refreshplugin?name=m2-load"`.
- SwiftBar must be running (`pgrep -x SwiftBar`, otherwise `open -g -a SwiftBar`).
- Check the output without SwiftBar: `env -i HOME=$HOME USER=$USER PATH=/usr/bin:/bin ./m2-load.15s.rb` — SwiftBar strips the environment the same way.
- Check that SwiftBar itself reaches the M2: `cat ~/Library/Application\ Support/SwiftBar/Plugins/Users/$USER/Projects/personal/swiftbar-m2-load/m2-load.15s.rb/last_seen` (SwiftBar's plugin data folder) must show a time under ~30 s old. If it does not while the manual run above works, SwiftBar lacks Local Network permission (System Settings → Privacy & Security → Local Network) — only Marat can grant it.
