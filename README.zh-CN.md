# NotchAgent

macOS 刘海区域的 AI 编码 Agent 实时状态面板。

NotchAgent 是 tame.gg 项目。它会显示本机 AI 编码工具的会话状态、工具调用、权限审批、问题和完成提示。

## 支持的工具

- Claude Code
- Codex
- Gemini CLI
- Cursor / Cursor CLI
- Copilot
- Trae / TraeCli
- Qoder
- Factory
- CodeBuddy / CodyBuddyCN
- OpenCode
- Kimi Code CLI
- Qwen Code
- Hermes
- AntiGravity
- Cline

## 从源码构建

需要 macOS 14+ 和 Swift 5.9+。

```bash
swift build
./build.sh
open .build/release/NotchAgent.app
```

## 工作方式

AI 工具触发轻量 hooks。hook bridge 会把规范化后的 JSON 事件通过按用户隔离的 Unix socket 发送给本机 NotchAgent 应用，应用实时更新刘海面板。

## 致谢

- 开发：tame.gg

## 许可证

MIT License。见 [LICENSE](LICENSE)。
