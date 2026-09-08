# homebrew-wigolo

Homebrew tap for [wigolo](https://github.com/KnockOutEZ/wigolo) — local-first web intelligence
for AI agents.

```sh
brew install KnockOutEZ/wigolo/wigolo
wigolo --version
```

The formula installs the **standalone build**: one prebuilt archive per platform, taken straight
off the wigolo release page. Nothing is compiled here, and the machine needs no Node runtime —
the executable carries its own. macOS (Apple silicon and Intel) and Linux (arm64 and x86_64) are
covered; on Alpine or another musl distribution, use `npm i -g wigolo` instead.

Every download is checksum-verified by Homebrew against the `sha256` in the formula, and each of
those comes from the release's own `SHA256SUMS`.

## How the formula is kept current

`Formula/wigolo.rb` is **generated, not hand-edited**. `scripts/formula.sh <release-tag>` reads
that release's `SHA256SUMS` and writes the whole formula from it, so the four `url`/`sha256`
pairs and the version can never drift apart or half-update.

`.github/workflows/bump.yml` runs that script and opens the version-bump PR. It is triggered
three ways:

| trigger | when | needs |
|---|---|---|
| `repository_dispatch` (`wigolo-release`) | the wigolo release workflow publishes the assets | a cross-repo token on the wigolo side |
| `schedule` (hourly) | always | nothing |
| `workflow_dispatch` | a maintainer asks | nothing |

All three resolve the target the same way: **the newest wigolo release carrying binary assets,
preferring a stable release over a prerelease.** The poke from the release workflow only says
that something was published — it cannot name the tag, so a scratch tag on the binary-only
prerelease channel can never walk into the formula behind a stable release. `workflow_dispatch`
takes an explicit tag, because that trigger has a person behind it.

The schedule is the guarantee and the dispatch is the accelerator: with the token in place the
PR appears seconds after a release, and without it the same PR appears within the hour. A
missing or revoked token delays the bump, it cannot lose it.

To bump by hand:

```sh
scripts/formula.sh v1.2.3 > Formula/wigolo.rb
```
