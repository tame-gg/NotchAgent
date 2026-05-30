# NotchAgent

Real-time AI coding agent status for the macOS notch.

NotchAgent is a tame.gg project. It lives in the MacBook notch/menu-bar area and shows what local AI coding agents are doing: active sessions, tool calls, approval prompts, questions, and completions.

## Supported Tools

- Claude Code
- Codex
- Gemini CLI
- Cursor and Cursor CLI
- Copilot
- Trae / TraeCli
- Qoder
- Factory
- OpenCode
- Kimi Code CLI
- Qwen Code
- Hermes
- AntiGravity
- Cline

## Build From Source

Requires macOS 14+ and Swift 5.9+.

```bash
swift build
./build.sh
open .build/release/NotchAgent.app
```

## How It Works

AI tools trigger lightweight hooks. The hook bridge forwards normalized JSON events to the local NotchAgent app over a per-user Unix socket, and the app updates the notch panel in real time.

## Credits

- Devs: tame.gg

## License

MIT License. See [LICENSE](LICENSE).
