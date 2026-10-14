# Project Guidelines

## Project Context

This project is a Flutter mobile app where users can create listings and wishlist cards from a mobile game called Pokemon TCG Pocket. The users can search for any card from the game find trade matches with other users so that they can coordinate trades and finish them in-game. The app is using Supabase as the database.

## UI/UX

For any UI/UX related tasks (design, review, implementation, improvements, planning), always invoke the ui-ux-pro-max skill.

### Styling

Always use Phosphor icons when icons are needed to be added or changed.

For primary and secondary colors, always import them from `config/app_colors.dart`.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (kristianskogberg/tcgp-trading-app-flutter) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five triage labels (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
