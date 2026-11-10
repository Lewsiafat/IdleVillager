<p align="center">English | <a href="README.zh-TW.md">繁體中文</a></p>

# IdleVillager

<p align="center"><strong>Your AI Agents at a Glance</strong> — a macOS menu bar status monitor for your AI agent "villagers".</p>

<p align="center"><img src="docs/images/hero.png" alt="IdleVillager menu bar counts and the expanded agent list" width="410"><br>
<em>Menu bar counts and the expanded agent list.</em></p>

**See the counts → find the Workspace / Tab / Pane → jump back to the original session in one click.**

Normally, the menu bar shows minimalist status counts for agents that are working, waiting for you, or idle. Expand it and the details appear as small characters you can recognize by brand, with light animation. Herdr is the primary integration target.

## Highlights

- **Menu bar:** a count for each state, with simple visual symbols
- **List:** Workspace / Tab / Pane / Agent hierarchy
- **Action:** click a session to locate it and switch back to Herdr
- **Characters:** Claude, Codex, Gemini, and Generic, with light animation
- **States:** Working, Needs Approval, Done, Idle, Error, Unknown
- **UI language:** English and Traditional Chinese (Simplified Chinese is not supported). The default is English. To switch, open Settings and change **Language** in the Appearance section; the change takes effect immediately.

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

An update rebuilds the app, then automatically quits the old version and opens the new one; it reopens the app even if you had quit it before updating. Uninstalling the plugin does not quit the running app; quit it from the menu bar popover with **Quit IdleVillager** (「結束 IdleVillager」 when the interface is Traditional Chinese). Herdr keeps the installed files when it removes a plugin, under `~/.config/herdr/plugins/github-installations/`.

If you can't see the icon in the menu bar after installing, the menu bar is usually out of space: MacBooks with a notch silently hide menu bar icons that don't fit. Hold ⌘ and drag other rarely used icons out of the menu bar to make room.

<p align="center"><img src="docs/images/demo.gif" alt="Click a session in the list to jump back to it in Herdr" width="410"><br>
<em>Click a session in the list to jump back to it in Herdr.</em></p>

## What's new

[v0.2.0](https://github.com/Lewsiafat/IdleVillager/releases/tag/v0.2.0) (2026-11-10) adds an English interface and an optional translucent background for the expanded list. See [`CHANGELOG.md`](CHANGELOG.md) for versions and changes.

## Trademarks

The name comes from the idle villager alert in *Age of Empires*. IdleVillager is not affiliated with or representing the game's publishers.

This repo does not ship third-party brand logos or other brand assets. Official Claude, Codex, and Gemini logos must be obtained separately, following each one's source, version, and terms of use. Where to put them is described in [`Sources/IdleVillagerApp/Resources/Brands/README.md`](Sources/IdleVillagerApp/Resources/Brands/README.md) (in Traditional Chinese). Without a logo, the character automatically falls back to the Generic villager.
