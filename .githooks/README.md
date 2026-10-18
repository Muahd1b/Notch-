# Staged file-size check

Hooks activate automatically for fresh clones on the managed Mac, cloud and
Server 2 development accounts. Their Git profiles conditionally select
`.githooks` for the registered repository remotes (HTTPS and SSH). No command
is needed after cloning. Other repositories keep their existing Git behavior,
and explicit local hook-manager settings retain precedence.

The checked-in `.codex/environments/environment.toml` installs hooks when Codex
creates a new worktree/environment. Infrastructure's setup also provisions the
full managed Git profile through `scripts/install-development-git-hooks.py`;
the cloud development-machine installer runs that provisioner too. Git and
Python 3 are required. No dependency install or application build is added.

`.githooks/install.sh` remains the idempotent environment bootstrap; matching
shared hooks are accepted, and incompatible existing hooks are never replaced.
The local Git config uses this checkout's absolute hook directory, so linked
worktrees run the same check even on older branches. Keep that checkout available;
after moving it, update `core.hooksPath` to its new `.githooks` directory.

Only added, modified, copied, renamed or type-changed **staged blobs** are checked.
Unstaged edits, unchanged files and deletions are ignored. Exactly 20,000 bytes
passes; 20,001 bytes fails (tokens = bytes / 4, including multibyte UTF-8).
The hook reads the index without modifying or staging files.

There is no reliable per-file Git metadata for agent authorship. The check
therefore covers authored text and exempts dependency lockfiles, known codegen
names/headers, generated/vendor/build/mirror directories, binary/media assets,
symlinks, submodules, LFS pointers and staged `.gitattributes` paths marked
`linguist-generated=true` or `linguist-vendored=true`. Mark additional real
generated output narrowly, for example:

```gitattributes
src/api/client.ts linguist-generated=true
```

Do not use generated attributes for authored source. Tests, documentation
(including Markdown) and CSS still have the token limit. Their exemption is
only from the separate **500 LOC source-file rule in AGENTS.md**, which agents
must follow when editing source; the hook enforces the token limit only.

If blocked, split by responsibility, update callers/imports/exports, run the
affected check and stage the split files. The hook prints those steps with
each file's staged byte and token counts. Existing oversized files are checked
when staged; no unrelated source refactoring is part of installing this hook.
