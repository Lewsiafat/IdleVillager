English | [繁體中文](README.zh-TW.md)

# IdleVillager

> **Your AI Agents at a Glance** — a macOS menu bar monitor for your AI agent "villagers".  
> See [`CHANGELOG.md`](CHANGELOG.md) for versions and changes.  
> This repo does not ship any third-party brand logos.

<!-- hero screenshot (#46): menu bar counts + expanded list -->

## Project identity

- **Product name**: IdleVillager
- **English tagline**: Your AI Agents at a Glance
- **Chinese positioning**: AI 村民工作狀態列 (a status bar for your AI villagers)
- **Name inspiration**: the idle villager alert in *Age of Empires*; not affiliated with or endorsed by the game's publishers.
- **First data source**: Herdr (an integration target only, not the product name).

## In one sentence

**See the counts → find the Workspace / Tab / Pane → jump back to the original session in one click.**

Day to day, the menu bar shows minimal counts of agents that are working, waiting for you, or idle. Expand it to see the details, with small brand-recognizable characters and light animation. Herdr is the primary integration target.

## Install

IdleVillager is distributed as a Herdr plugin. Installing it builds the app from source on your own Mac, so you don't have to deal with macOS blocking unsigned apps.

Requirements:

- macOS 14 or later.
- Herdr 0.9.5 or later, with the Herdr TUI in use.
- Xcode Command Line Tools (provides the Swift 6 compiler). If you don't have them yet, run `xcode-select --install`.

Install:

```sh
herdr plugin install Lewsiafat/IdleVillager
```

Herdr first shows you what the plugin contains and asks for confirmation, then builds the app, which takes about one to two minutes. When the build finishes, IdleVillager opens automatically, and it also opens every time the Herdr server starts. To reopen it after you've quit it, run:

```sh
herdr plugin action invoke launch --plugin idlevillager
```

Update and uninstall:

```sh
herdr plugin update idlevillager
herdr plugin uninstall idlevillager
```

An update rebuilds the app, then automatically quits the old version and opens the new one; it reopens the app even if you had quit it before updating. Uninstalling the plugin does not quit the running app; quit it with **結束 IdleVillager** (Quit IdleVillager) in the menu bar popover. Herdr keeps the installed files when it removes a plugin, under `~/.config/herdr/plugins/github-installations/`.

If you can't see the icon in the menu bar after installing, the menu bar is usually out of space: MacBooks with a notch silently hide menu bar icons that don't fit. Hold ⌘ and drag other rarely used icons out of the menu bar to make room. For distribution research and details, see [`docs/08-distribution.md`](docs/08-distribution.md) (in Traditional Chinese).

<!-- demo GIF (#46): click a session to jump back to Herdr -->

## First release scope

- Menu bar: a count for each state, with simple visual symbols
- List: Workspace / Tab / Pane / Agent hierarchy
- Action: click a session to locate it and switch back to Herdr
- Characters: recognition and animation asset specs for Claude, Codex, Gemini, and Generic
- States: Working, Needs Approval, Done, Idle, Unknown / Error
- UI language: currently Traditional Chinese

## Documentation

The documents below are written in Traditional Chinese.

- [`docs/01-product-requirements.md`](docs/01-product-requirements.md): product requirements, scope, and acceptance criteria
- [`docs/02-ui-ux-spec.md`](docs/02-ui-ux-spec.md): visuals and interaction for the menu bar and the expanded list
- [`docs/03-agent-states.md`](docs/03-agent-states.md): state definitions and counting rules
- [`docs/04-assets-animation.md`](docs/04-assets-animation.md): missing artwork, asset specs, and animation actions
- [`docs/05-herdr-integration.md`](docs/05-herdr-integration.md): integration boundaries, APIs still to be verified, and the switching flow
- [`docs/06-architecture-decisions.md`](docs/06-architecture-decisions.md): technical direction, constraints, and decisions
- [`docs/07-brand-identity.md`](docs/07-brand-identity.md): IdleVillager brand, icons, naming, and visual vocabulary
- [`docs/08-distribution.md`](docs/08-distribution.md): distribution research (Herdr plugin, GitHub Releases, Homebrew Cask)
- [`docs/09-release-process.md`](docs/09-release-process.md): versioning rules, how to write the CHANGELOG, and release steps
- [`CHANGELOG.md`](CHANGELOG.md): changes in each version
- [`planning/roadmap.md`](planning/roadmap.md): P0/P1/P2 development phases and completion criteria
- [`planning/open-questions.md`](planning/open-questions.md): environment and technical questions not yet settled

## Repository layout

```text
IdleVillager/
├── README.md                  # English README
├── README.zh-TW.md            # Traditional Chinese README
├── CHANGELOG.md
├── CLAUDE.md                  # project instructions for development agents
├── GLOSSARY.md                # project glossary
├── Package.swift              # Swift Package definition
├── herdr-plugin.toml          # Herdr plugin manifest and the single source of the version number
├── Sources/
│   ├── IdleVillagerCore/      # core logic such as state normalization and the Herdr adapter
│   └── IdleVillagerApp/       # SwiftUI menu bar app
│       └── Resources/Brands/  # where third-party brand logos go (only a README by default)
├── Tests/
│   └── IdleVillagerCoreTests/
├── assets/
│   └── brand/                 # IdleVillager's own menu bar and popover marks (SVG)
├── distribution/              # make-app.sh, launch.sh, release-notes.sh
├── docs/
│   ├── 01-product-requirements.md … 09-release-process.md
│   ├── adr/                   # architecture decision records
│   └── agents/                # workflow notes for development agents
├── planning/
│   ├── roadmap.md
│   └── open-questions.md
└── specs/                     # per-feature specs and walkthroughs
```

## Notes for development agents

Before you start, read `CLAUDE.md` and the documents in `docs/` and `planning/`. Run the tests with `swift test` and the development build with `swift run IdleVillagerApp`. Never assume an agent is idle based on a single signal such as low CPU or stopped output, and never claim an API is verified unless it has been tested in the user's environment.

## Assets and trademarks

This repo **does not ship any third-party brand assets**. `assets/brand/` contains only IdleVillager's own marks. Official Claude, Codex, and Gemini logos must be obtained separately, following each one's source, version, and terms of use; see [`Sources/IdleVillagerApp/Resources/Brands/README.md`](Sources/IdleVillagerApp/Resources/Brands/README.md) (in Traditional Chinese) for where to put them and what format they need. Without a logo, the character automatically falls back to the Generic villager.
