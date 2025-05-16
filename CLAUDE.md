# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Build: None (shell scripts repository)
- Lint: `shm perms` (check/fix permissions)
- Test: No formal test suite (check script logic manually)

## Coding Style

- Header: `#!/usr/bin/env bash` first line, followed by filename with creation/update dates and copyright
- Variables: Use UPPERCASE for global/exported vars, lowercase for local vars
- Functions: Use snake_case for function names
- Indentation: 4 spaces for indentation
- Error handling: Use early returns/exits with error codes
- Comments: Begin with `# ` and describe purpose
- Line length: Keep under 80 characters when possible
- Quotes: Prefer double quotes for variable expansion, single quotes for literals

## Conventions

- All scripts copyright Mark Constable (AGPL-3.0)
- Follow defensive coding practices (use `[[ ]]` instead of `[ ]`, etc.)
- Check for required privileges before executing privileged operations
- Provide usage information with `-h` or when missing required arguments
- Source environment variables from host configuration file
- Use DEBUG flag for execution tracing (set -x/+x)
- Use clear, consistent naming conventions

