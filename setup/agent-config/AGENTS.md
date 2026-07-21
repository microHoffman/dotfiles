# Global Codex Instructions

When using Plan mode or otherwise asking the user for required input, wait for
the answer. Do not auto-resolve a question unless the user explicitly asks for
auto-resolution in the current thread.

## Browser Automation

Use `agent-browser` for ad-hoc website interaction, authenticated browsing,
data extraction, screenshots, and exploratory smoke testing. Run
`agent-browser --help` for its current commands.

Use a repository's existing `@playwright/test` setup when creating or updating
repeatable E2E tests that belong in the codebase, or when debugging its existing
Playwright suite. Keep committed Playwright tests and configuration as the
project's regression-test layer; `agent-browser` does not replace them.
