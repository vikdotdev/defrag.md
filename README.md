# `defrag.md`

/diːˈfræɡmənd/ — *defragment* your markdown.

A tool for managing reusable markdown fragments that can be composed into larger documents. Useful for maintaining personal documentation, LLM instruction sets, or any content you want to mix and match across projects.

## Use case: managment of LLM intrstructions

Often projects have their own `*.md` rule/context files that provide LLMs with context about the project (architecture/design/styling/etc). This leaves no place for user-defined instructions that don't belong in the project (user-specific workflows/preferences/etc).

_A way_ out of this problem is to have a git-ignored `*.local.md` file that contains such user preferences. Keeping such ignored files outside of version control can get messy, especially if user wishes to carry their LLM instructions across multiple machines.

### Solution

Split LLM rule/context file into individual `*.md` fragment files and build specific context file for specific project/LLM tool. Here's an example of what a repository could look like:

```
my-ai-rulesets/
├── git/                   # Shared git instructions
│   └── fragments/
│       └── *.md
├── ruby/                  # Shared Ruby instructions
│   └── fragments/
│       └── *.md
├── rails/                 # Shared Rails instructions
│   └── fragments/
│       └── *.md
├── my_rails_project/      # Project-specific instrutions
│   ├── fragments/
│   │   └── *.md
│   └── default.manifest   # References git/, ruby/, rails/, and local fragments
└── another_rails_project/ # Another project reusing same/similar fragments
    ├── fragments/
    │   └── *.md
    └── default.manifest
```

## Quick Start

**Linux (x86_64):**
```bash
curl -L https://github.com/vikdotdev/defrag.md/releases/latest/download/defrag-x86_64-linux-musl -o ~/.local/bin/defrag && chmod +x ~/.local/bin/defrag
```

**macOS (Apple Silicon):**
```bash
curl -L https://github.com/vikdotdev/defrag.md/releases/latest/download/defrag-aarch64-macos -o /usr/local/bin/defrag && chmod +x /usr/local/bin/defrag
```

**macOS (Intel):**
```bash
curl -L https://github.com/vikdotdev/defrag.md/releases/latest/download/defrag-x86_64-macos -o /usr/local/bin/defrag && chmod +x /usr/local/bin/defrag
```

Then:
```bash
# Initialize a store (creates config automatically)
defrag init ~/my-ai-rulesets

# Create and build a collection
defrag new my-collection
# edit ~/my-ai-rulesets/my-collection/default.manifest and add fragments
defrag build ~/my-ai-rulesets/my-collection/default.manifest --out ~/my_project/CLAUDE.local.md
```

## CLI Commands

### Create New Collection
```bash
defrag new <name> [--no-manifest]
```
Creates a new fragment collection with proper directory structure.

### Validate Manifest
```bash
defrag validate <manifest-path>
```
Validates manifest syntax and checks that all referenced fragments exist.

### Build
```bash
defrag build <manifest-path> [--out <file>]
```
Compiles fragments from a manifest into a single markdown file.

```bash
# Build with default output (build/<collection>.<manifest-name>.md)
defrag build my-collection/default.manifest

# Build with custom output
defrag build my-collection/default.manifest --out path/to/output.md

# Build all *.manifest files in current directory
defrag build --all
```

### Build and Link
```bash
defrag build-link --manifest <path> --link <symlink-path>
```
Builds documentation and creates a symlink to the output.

## Dependencies

**Build time**: Zig compiler, libcmark

**Runtime**: None (single static binary)

## Manifest Format

Manifests have two sections: `[config]` and `[fragments]`.

```
[config]
heading_wrapper_template = "{fragment_id}"

[fragments]
# Comments start with #
| top-level-fragment
|| nested-fragment
||| deeply-nested-fragment
| another-top-level
```

### Config Options

- `heading_wrapper_template`: Template for fragment headings. Use `{fragment_id}` as placeholder. For example: `heading_wrapper_template = "Rule: {fragment_id}"`.

### Nesting Levels

- `|` = Level 1 (becomes `# heading`)
- `||` = Level 2 (becomes `## heading`)
- `|||` = Level 3 (becomes `### heading`)
- Up to 6 levels supported

### Cross-Collection References

Reference fragments from other collections using `collection/fragment` syntax:

```
[fragments]
| local-fragment
| shared/common-fragment
```

Requires stores configured in `~/.config/defrag/config.json`:
```json
{
  "stores": [{"path": "~/my-ai-rulesets", "default": true}]
}
```

## Writing Fragments

- Fragments are standard Markdown files stored in `<collection>/fragments/*.md`
- Use any heading levels you want - they'll be automatically normalized based on hierarchy
- Keep fragments small and focused for easy composition

## Glossary

- **Fragment**: A markdown file with focused topic
- **Collection**: A directory containing `fragments/` and manifest file(s)
- **Manifest**: A file describing which fragments to include and their hierarchy

## Contributing

1. Clone the repository
2. Make changes
3. Run tests: `zig build test`
4. Submit a pull request

### Building

```bash
zig build              # Build the binary
zig build test         # Run all tests
```

### Releasing

Update version in `build.zig.zon`, then:

```bash
./scripts/release.sh
```
