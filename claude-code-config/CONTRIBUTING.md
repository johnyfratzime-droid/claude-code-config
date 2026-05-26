# Contributing

## How to Contribute

### Reporting Issues

1. Check existing issues first
2. Include:
   - Platform (macOS/Linux/Windows)
   - Claude Code version (`claude --version`)
   - Bash version (`bash --version`)
   - jq version (`jq --version`)
   - Steps to reproduce
   - Expected vs actual behavior

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test on at least one platform
5. Commit with a descriptive message
6. Push and open a PR

### Commit Message Convention

```
type: short description

Longer description if needed.

type: feat, fix, docs, refactor, hooks, config
```

Examples:
```
feat: add GPT-4o model mapping to OpenRouter config
fix: handle missing jq in statusline on Windows
hooks: add rate limit pattern to model router
docs: update INSTALL.md with Windows Terminal requirements
```

## Adding New Routing Patterns

Edit `hooks/model-router.sh` and add regex patterns to the appropriate array:

```javascript
var opusPat = [
  /your-new-pattern/,  // e.g., /threat model/
];
var sonnetPat = [
  /your-new-pattern/,  // e.g., /endpoint/
];
```

**Guidelines:**
- Opus patterns: architecture, security, critical production decisions
- Sonnet patterns: implementation, debugging, analysis, integration
- Keep patterns specific — avoid false positives
- Test with: `echo '{"prompt": "your test prompt"}' | bash hooks/model-router.sh`

## Adding New Hooks

1. Create a new `.sh` file in `hooks/`
2. Make it executable: `chmod +x hooks/my-hook.sh`
3. Register it in `settings.json` under the appropriate lifecycle event
4. Document it in `ARCHITECTURE.md`

### Hook Contract

**Input:** JSON from stdin (format depends on lifecycle event)
**Output:** Text to stdout (Claude Code reads this)
**Exit code:** 0 = success, non-zero = error
**Timeout:** Defined in `settings.json` (default: 5 seconds)

## Testing

### Manual Testing

```bash
# Test model router
echo '{"prompt": "debug the authentication middleware"}' | bash hooks/model-router.sh

# Test quota monitor
bash hooks/quota-monitor.sh
echo $?  # Should be 0

# Test status line
echo '{"model": {"display_name": "Claude Haiku 3.5"}, "cwd": "'$PWD'", "context_window": {"used_percentage": 42, "context_window_size": 200000}}' | bash hooks/statusline.sh
```

### Shell Check

```bash
shellcheck hooks/*.sh
```

## Code of Conduct

- Be respectful
- Test before submitting PRs
- Document your changes
- Follow existing conventions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
