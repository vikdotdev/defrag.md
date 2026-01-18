# Roadmap

## Planned Features

### `version` command
Simple version command.

### `doctor` command
Health check command to diagnose configuration issues:
- Validate config.json syntax
- Check all store paths exist
- Check collections have valid structure (fragments/ dir, manifest files)
- Report orphaned fragments (not referenced in any manifest)
- Warn about missing referenced fragments

### Improved `validate` output
- Summary at the end showing total/valid/missing across all collections
- Option for quiet mode (only show errors)
- Option for short mode (only show summary)
- Option for verbose mode (show fragment paths)
- Group output by collection when using `--all`

### Color support
- Colored output for errors (red), warnings (yellow), success (green)
- Respect `NO_COLOR` environment variable
- Add `--no-color` flag
- Detect TTY and disable colors when piping

### Standard Unix help format
Current help is decent. Improvements to align with conventions (ls, git, curl):
- Options: use consistent alignment like `-o, --out <path>   description`
- Add `--help` and `--version` to OPTIONS section
- Consider grouping global options (--config) separately

Reference (GNU coreutils style):
```
Usage: cmd [OPTION]... [FILE]...
Description sentence.

  -a, --all           description here
  -o, --out <path>    description here
```

## Ideas to Explore

- Watch mode for `build` (rebuild on file changes)
- Config init wizard (interactive store setup)
