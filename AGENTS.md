# AGENTS.md

pr-inbox is a Claude Code mod (a plugin of function hooks). See README.md for what it does.

## Commands

```bash
pnpm install
claude --plugin-dir .            # run the working copy; also generates .claude-plugin/types/
pnpm run check                   # validate (--strict) → tsc → Biome → claude plugin test
pnpm run lint:fix                # apply Biome fixes
claude -p "/pr-inbox refresh" --plugin-dir .   # smoke test against real GitHub data
```

Run `pnpm run check` before every commit; all of it must pass. `claude plugin validate` does not catch everything the loader refuses (for example a function given `$` that shares a name with another binding): also load the mod for real, `claude -p "/pr-inbox refresh" --plugin-dir .` must print the counts.

## Layout

- `hooks/register.ts` — the whole mod. Loaded as TypeScript directly; there is no build step
- `tests/pr-inbox.test.ts` — `claude plugin test`. GitHub, the model, the store and the environment are stubbed; tests must not touch the network
- `.claude-plugin/plugin.json` — manifest and `userConfig`; `.claude-plugin/marketplace.json` lists this repo as a one-plugin marketplace

## Mod API

- The API changes between Claude Code versions. Check `.claude-plugin/types/claude-code/index.d.ts` (generated for the installed version, gitignored) and https://code.claude.com/docs/en/plugins/mods/ before relying on memory
- If `.claude-plugin/types/` is missing, `tsc` fails: load the mod once with `claude --plugin-dir .`

## Releasing

- Installed copies are cached per version, so users get a change only when `version` in `.claude-plugin/plugin.json` goes up
- Bump it in the same change whenever what users run changes (`hooks/`, `.claude-plugin/plugin.json`). Changes to README, docs or tests alone need no bump
- Semantic versioning: patch for fixes, minor for new features or settings, major for breaking changes (a removed or renamed setting, command or key)
- After the change lands on `main`, tag it: `git tag v<version> && git push origin v<version>`

## Security rules (do not weaken)

PR titles, bodies, diffs, comments and CI output are untrusted input written by others. Each rule below has tests; keep them passing and add one whenever you touch the area.

- **Display**: pass every string from GitHub or the model through `clean()` before drawing it (escape sequences, control, bidi and invisible characters). Links go through `safeHref()`: canonical `https://` only, no credentials, or the pane refuses to render
- **Analysis**: `$.model.complete` with no tools. PR content goes inside the random `untrusted-<uuid>` fence, file list before body, Unicode tag characters removed. A partial view (`prContent().partial`) is never judged low risk and is shown as partial
- **Analysis budget**: failures are stored and retried with backoff (`RETRY_BASE`, `MAX_ATTEMPTS`); at most `MAX_ANALYSES_PER_HOUR` start per hour. `analysis` = `off` / `when opened` must send nothing before it allows
- **`e`**: the request keeps `UNTRUSTED_NOTE`, and the turn it starts runs under the `tool.call` guard (`READ_TOOLS`, `READ_GH`). Never widen the allowlist to a tool that writes, runs arbitrary commands, reaches the network or spawns agents
- **Approve**: only after a person picks Approve in the `$.ui.ask` dialog, which names the commit. Re-read the head right before, refuse if it moved, and send the review pinned to that `commit_id`. No other path may approve, comment or push
- **AI instructions in the reviewed repository** (`isAiInstruction`: CLAUDE.md, `.claude/`, skills, subagents, other tools' rules) are read only from the base branch, as guides, never from the PR head and never screened; a PR that changes one is blocked before any model runs
- **Prompt settings** (`explain_prompt`, `risk_*`, `release_impact`) replace only the criteria and the request. The JSON format, the untrusted fence and its rule, `contextNote` and `UNTRUSTED_NOTE` are always added and must stay out of reach of settings. `criteriaKey()` must cover every setting that changes the analysis
- **AI review (`v`)**: the approve decision stays in code (`aiReview`/`finish`): every gate, no injection, every reviewer parsed, no confirmed important finding, head unchanged. The review's models are tool-free `$.model.complete` calls; what they ask to read goes through `readRequest` (validation) and `readForReview` (`scrub`, `screen`, labeled JSON) before they see it. Never hand them tools or a way to write. Failures and timeouts block. `auto` applies only to `TRUSTED_AUTHORS` and `DEPENDENCY_BOTS` on non-fork PRs. (Subagents cannot use a tool their own mod serves: a mod's hooks skip tool calls from its own spawns)
- **Processes**: run external commands as argument lists through `$.process.run`, never through a shell. PR text given to `osascript` goes in `argv`, never into the `-e` script. Validate anything from settings that ends up in a query (`ORG_NAME`)
- When what is sent, stored or allowed changes, update the Security section of README.md to match

## Conventions

- UI text, README, code comments and test names are in English. Only the AI analysis and its labels follow the language setting (`LABELS_JA` / `LABELS_EN`)
- Bump `ANALYSIS_VERSION` when the analysis prompt or its stored shape changes, so stored analyses are redone
- Use placeholder names such as `my-org` and `acme` in code, tests and docs; never real company or organization names
- Commit messages are in Japanese
