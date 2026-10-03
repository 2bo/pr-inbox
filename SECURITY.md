# Security policy

## Reporting a vulnerability

Please do not open a public issue. Report it privately through **Security → Report a vulnerability** on this repository (GitHub private vulnerability reporting). Include the steps or the PR content that reproduces it.

## In scope

pr-inbox reads pull requests written by other people, so anything that lets PR content (title, body, diff, comments, CI output) or a GitHub response do more than it should, for example:

- approving, commenting or pushing without the user's confirmation, or approving a commit other than the one shown
- getting past the read-only guard on the `e` (Explain / Diagnose) turn
- injecting terminal escape sequences or misleading text into the pane, toasts or dialogs
- sending data to the model or anywhere else beyond what the README describes

Weaknesses in Claude Code itself or in the GitHub CLI belong to those projects.

## Supported versions

Only the latest version on `main` is supported.
