# Global Codex Instructions

When using Plan mode or otherwise asking the user for required input, wait for
the answer. Do not auto-resolve a question unless the user explicitly asks for
auto-resolution in the current thread.

## Request scope

Treat requests to answer, explain, inspect, review, diagnose, recommend, or
report as non-mutating. Relevant inspection and checks are allowed, but do not
edit files, install packages, change configuration or services, or modify remote
systems unless the user asks for implementation.

An informational question about a possible change is not authorization to make
it. If the intent is unclear and acting would create a meaningful state change,
ask first.

## Declarative system configuration

Use the project's declared dependency and runtime tooling when available. Add a
tool or service to Nix/dotfiles only when it is intended to be part of that
machine's reusable baseline.

Keep one-off tools and runtime data out of dotfiles. If the correct scope is
unclear, ask before changing persistent system or host configuration.

## Browser Automation

Use `agent-browser` for ad-hoc website interaction, authenticated browsing,
data extraction, screenshots, and exploratory smoke testing. Run
`agent-browser --help` for its current commands.

If an agent-browser command is blocked by the Codex sandbox's runtime socket,
local-binding, or network restrictions, retry that command with scoped
escalation so the configured auto-reviewer can evaluate it. Do not fall back to
public APIs or search solely because the sandboxed attempt was blocked. Treat
missing shared libraries or browser-install errors as host setup failures.

Use a repository's existing `@playwright/test` setup when creating or updating
repeatable E2E tests that belong in the codebase, or when debugging its existing
Playwright suite. Keep committed Playwright tests and configuration as the
project's regression-test layer; `agent-browser` does not replace them.
