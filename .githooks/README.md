# Staged file-size check

After cloning, run `sh .githooks/install.sh` (requires Git and Python 3).
Git does not activate tracked hooks automatically. Run this setup in every
development checkout, including cloud setup scripts. Existing hook managers
must call `.githooks/pre-commit` before their other checks; the installer refuses
to replace an existing hook.
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
