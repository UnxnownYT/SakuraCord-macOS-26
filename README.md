<div align="center">
  <img src="Brand/Banners/SakuraCord-README-Header.svg" width="1200" alt="SakuraCord">

  <p>A fast, native Discord client shaped around SwiftUI, macOS, and the way desktop chat should feel.</p>

  <p>
    <a href="https://github.com/UnxnownYT/SakuraCord-macOS-26/releases/latest"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/release/SakuraCordApp/SakuraCord.svg?label=Release&amp;mode=dark&amp;size=sm"><img alt="Latest release (The OS 26 Fork)" src="https://shieldcn.dev/github/release/SakuraCordApp/SakuraCord.svg?label=Release&amp;mode=light&amp;size=sm"></picture></a>
    <a href="https://discord.gg/hWNwFXkUTP"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/discord/online-members/hWNwFXkUTP.svg?variant=branded&amp;mode=dark&amp;size=sm"><img alt="Discord online members" src="https://shieldcn.dev/discord/online-members/hWNwFXkUTP.svg?variant=branded&amp;mode=light&amp;size=sm"></picture></a>
    <a href="https://roadmap.sakuracord.app"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Roadmap-D9578B.svg?logo=ri%3AFaMap&amp;logoColor=white&amp;mode=dark&amp;size=sm"><img alt="The SakuraCord Roadmap" src="https://shieldcn.dev/badge/Roadmap-D9578B.svg?logo=ri%3AFaMap&amp;logoColor=white&amp;mode=light&amp;size=sm"></picture></a>
  </p>

  <p>
    <a href="https://github.com/SakuraCordApp/SakuraCord/actions/workflows/ci.yml"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/ci/SakuraCordApp/SakuraCord.svg?workflow=ci.yml&amp;branch=main&amp;label=Build&amp;variant=secondary&amp;mode=dark&amp;size=xs"><img alt="Build status" src="https://shieldcn.dev/github/ci/SakuraCordApp/SakuraCord.svg?workflow=ci.yml&amp;branch=main&amp;label=Build&amp;variant=secondary&amp;mode=light&amp;size=xs"></picture></a>
  </p>

  <p>
    <a href="https://github.com/UnxnownYT/SakuraCord-macOS-26/releases/latest">Download the Latest DMG</a>
    ·
    <a href="#build-from-source">Build from source</a>
    ·
    <a href="docs/README.md">Documentation</a>
  </p>
</div>

---

## A Discord client that belongs on macOS

The SakuraCord for macOS 26 fork preserves the visual language and familiar 
rhythm of Discord, then reimagines the experience through Liquid Glass and 
native macOS design instead of wrapping the web app in an Electron runtime.

The result keeps Discord's familiarity while looking and behaving like a native
Mac app.

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🌸 Native by design</h3>
      SwiftUI surfaces, real macOS windows, menus, shortcuts, settings, and
      Liquid Glass presentation.
    </td>
    <td width="50%" valign="top">
      <h3>⚡ Responsive conversations</h3>
      Native timeline rendering, bounded media work, and shared caches keep
      conversations responsive.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎙️ Voice and video</h3>
      Native device controls, guild voice, direct-message calls, Opus audio,
      H.264 video, voice-server migration, and DAVE support.
    </td>
    <td width="50%" valign="top">
      <h3>✨ Rich Discord content</h3>
      Embeds, Components V2, modals, stickers, GIFs, uploads, custom emoji,
      slash commands, and media previews where Discord capability gates allow.
    </td>
  </tr>
</table>

## Download

Download the [latest SakuraCord Forked DMG](https://github.com/UnxnownYT/SakuraCord-macOS-26/releases/latest)
for macOS 26.4 or newer, open it, and move SakuraCord into Applications.

Current releases are ad-hoc signed rather than notarized, so macOS may require
approval from **System Settings → Privacy & Security** on first launch.

This current SakuraCord fork is an independent project and is not affiliated 
with Discord. Discord does not provide a supported third-party platform for 
normal-account clients, so compatibility can change as Discord evolves. Please 
note that using an external client from discord is breaking ToS and can get you 
banned, though it is very rare for this occurance. **Use at your own risk.**

## Build from source

Building this SakuraCord fork requires at least macOS 26.4+, Xcode 
26.6+ with Swift 6.3.3+ and its Metal Toolchain, and Git. Install the shader
compiler if you haven't already with:
`xcodebuild -downloadComponent MetalToolchain`.

```sh
git clone https://github.com/UnxnownYT/SakuraCord-macOS-26.git
cd SakuraCord-macOS-26
./script/install_git_hooks.sh
git config --local --get core.hooksPath
./script/setup_local_signing_identity.sh
./script/build_and_run.sh --offline
```

The hooks command must print `.githooks`. The offline demo does not contact
Discord and is the most safest way to explore the app from source. Developers 
can find authenticated launch modes, focused fixtures, validation commands, 
and local credential guidance in the [development guide](docs/DEVELOPMENT.md).

## Contributing and support

Start with the [documentation task index](docs/README.md) to find the owner and
verification for a change. Development pull requests target `nightly`; install
the repository hooks before committing or pushing.

For a bug report, include reproduction steps, expected and actual behaviour, and
the app version/release track. The [support recipe](docs/DEVELOPMENT.md#report-a-problem)
explains how to collect a support summary and sanitized diagnostics. Use the
[issue tracker](https://github.com/UnxnownYT/SakuraCord-macOS-26/issues) or the
[Official Sakuracord Discord community](https://discord.gg/hWNwFXkUTP).

## Repository guide

| Path | Purpose |
| --- | --- |
| `App/` | Native macOS application and plugin-host targets |
| `Packages/` | Models, Discord protocol, persistence, message rendering, media, and plugin contracts |
| `Brand/` | Logos, banners, and brand metadata |
| `Config/` | Application entitlements |
| `docs/` | Canonical architecture, protocol, testing, development, and release guides |
| `script/` | Build, test, quality, packaging, and release entry points |

SwiftPM manifests are the build source of truth;
`SakuraCord.xcworkspace` is a convenience entry point. Start with the
[documentation index](docs/README.md), then use the
[architecture guide](docs/ARCHITECTURE.md) or
[protocol baseline](docs/PROTOCOL_BASELINE.md) for deeper work.

## Follow along with the Official SakuraCord

<table>
  <tr>
    <td align="center" width="33%">
      <h3>Discord</h3>
      Talk with the official community, share feedback, and follow day-to-day project
      conversation.<br><br>
      <a href="https://discord.gg/hWNwFXkUTP"><strong>Join the Offical SakuraCord server →</strong></a>
    </td>
    <td align="center" width="33%">
      <h3>Roadmap</h3>
      Browse the official SakuraCord's planned work, active development, completed features, and community
      requests.<br><br>
      <a href="https://roadmap.sakuracord.app"><strong>Explore the roadmap →</strong></a>
    </td>
    <td align="center" width="33%">
      <h3>Releases</h3>
      Read SakuraCord's release notes and download the newest packaged build for macOS 27.<br><br>
      <a href="https://github.com/SakuraCordApp/SakuraCord/releases/latest"><strong>Get the latest build →</strong></a>
    </td>
  </tr>
</table>

<div align="center">
  <sub>Made for macOS with Swift, SwiftUI, and a little sakura pink. (a forked version for macOS 26.4 and above)</sub>
</div>
