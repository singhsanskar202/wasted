# Wasted Documentation

This directory contains comprehensive guides for understanding and working on the Wasted screen time tracking app.

## Quick Navigation

- **[Product Guide](./product-guide.md)** — Vision, user journey, features, monetization, and launch readiness
- **[Design Guide](./design-guide.md)** — Visual system, component patterns, typography, and interaction design
- **[Architecture Guide](./architecture-guide.md)** — System architecture, data flow, targets, and key algorithms
- **[Implementation Guide](./implementation-guide.md)** — Code patterns, SwiftUI conventions, testing strategies, and development practices

## What each guide covers

### Product Guide
The product guide defines Wasted's thesis, target user, and monetization strategy:
- **Vision** — selling the truth, not control; the mirror positioning
- **Features** — tracked apps, Dynamic Island, 30-min nudges, daily receipt, reality check
- **User journey** — day-by-day from first launch through trial expiry through purchase
- **Monetization** — 7-day free trial, $9.99 one-time lifetime purchase, no subscription
- **Success metrics** — activation, engagement, trial-to-paid conversion, retention targets
- **Launch checklist** — critical path dependencies, App Store compliance, decision gates
- **Post-launch roadmap** — approved only if retention >30% (iPad, Pro tier, price increase)

*When to read:* when understanding the product's purpose and direction, planning features, or making pricing/positioning decisions.

### Design Guide
The design guide defines Wasted's visual identity and user experience principles:
- **Color system** — the palette (canvas, ink, alarm) and usage rules
- **Typography** — serif for mirror voice, sans for interface
- **Components** — buttons, cards, heatmap, receipt, paywall
- **Motion** — entrance animations, haptics, reduced-motion support
- **Onboarding flow** — the 6-step sequence from Hook to Done
- **Live Activity rendering** — Dynamic Island surfaces and ticking behavior

*When to read:* when implementing UI, checking design compliance, or adding new screens.

### Architecture Guide
The architecture guide explains how Wasted is structured and how its components interact:
- **System overview** — the four Xcode targets and their responsibilities
- **Data flow** — usage tracking, storage, Live Activity updates
- **Key algorithms** — nudge gate, trial clock, historical peaks, reality checks
- **Extension communication** — how the background monitor and main app sync state
- **Error handling & resilience** — graceful degradation when things go wrong
- **Testing strategy** — unit test patterns, device testing, CI/CD

*When to read:* when understanding how a feature fits into the system, architecting new functionality, or debugging cross-component issues.

### Implementation Guide
The implementation guide covers code style, patterns, and best practices:
- **Code style** — naming, formatting, comments
- **SwiftUI patterns** — state management, composition, reactivity
- **Data storage** — App Group UserDefaults, Codable models, date handling
- **Testing** — unit tests, injecting dependencies, manual testing
- **Extension patterns** — DeviceActivityMonitorExtension specifics, type-checker tips
- **Performance** — avoiding main-thread blocks, view re-renders, timers
- **Git hygiene** — commit messages, pre-commit checks

*When to read:* when writing code, setting up tests, or reviewing PRs.

---

## How to use these guides

### New to the project?
1. Start with **Product Guide** to understand what Wasted is and why it exists
2. Read **Architecture Guide** to see how the app is structured
3. Read **Design Guide** to see how it looks and feels
4. Reference **Implementation Guide** when you start coding

### Adding a new feature?
1. Check **Architecture Guide** for how to integrate it into the system
2. Verify design compliance in **Design Guide**
3. Follow patterns from **Implementation Guide** for code style

### Fixing a bug?
1. **Architecture Guide** explains data flow and where state lives
2. **Implementation Guide** shows testing patterns
3. **Design Guide** confirms expected behavior and appearance

### Reviewing code?
Use **Implementation Guide** as a checklist for style, patterns, and best practices.

---

## Key principles

**Wasted is a mirror, not a blocker.** The app exists to show users how much time they've lost, without judgment or intervention. Every design and architectural decision serves this purpose.

**Small, focused files.** Each file, class, and function has a single responsibility. Models don't import views. Storage doesn't import UI. This isolation makes testing possible and bugs localized.

**Trust the frameworks.** SwiftUI, ActivityKit, Family Controls—they work. Don't layer your own state machine on top unless the framework provably fails.

**No premature abstraction.** If three similar lines exist, leave them. If they drift into five, consolidate. Three is pattern-seeking; five is waste.

---

## Companion files

- `superpowers/specs/2026-07-06-mirror-polish.md` — Design spec for the Mirror Polish pass (Wasted 1.0)
- `superpowers/plans/2026-07-09-launch-pass.md` — Implementation plan for launch readiness
- `open-problems.md` — Known issues and future work

---

## Staying in sync

These guides are snapshots of the project as of July 2026. As the codebase evolves:

- Update the guides when core architecture changes
- Keep examples current with the actual code
- Note when constraints (like provisioning, entitlements) shift
- Link to related decisions in git commit messages

If something in the guides doesn't match the code, the code wins. File an issue or update the docs.
