TODO
====

A list of things to be improved, in no particular order:

* Try and manage zig with pnpm, rather than system commands
* Improvements to PR into `zx`:
  * Paths being `LazyPath` instead of `[]const u8`
  * Allow `zx fmt` to work on several files, allowing its usage on `lint-staged`
* Add codespell to pre-commit
