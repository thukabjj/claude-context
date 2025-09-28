# Development Rules & Standards

## Mandatory Tooling Requirements

All repositories and development workflows MUST follow these standardized tools and practices:

### Shell Environment
- **REQUIRED**: ZSH shell for all development operations
- **RATIONALE**: Consistent shell environment across all platforms
- **USAGE**: All scripts, documentation, and automation must assume ZSH

### Python Development
- **REQUIRED**: `uv` for dependency management and virtual environments
- **REQUIRED**: `uvx` for running Python tools and packages
- **FORBIDDEN**: `pip`, `pipenv`, `poetry`, `conda` (except in legacy migration scenarios)
- **RATIONALE**: Faster dependency resolution, better reproducibility
- **USAGE**:
  - `uv add <package>` for adding dependencies
  - `uv run <command>` for running in virtual environment
  - `uvx <tool>` for running Python tools

### Node.js Development
- **REQUIRED**: `pnpm` for package management
- **FORBIDDEN**: `npm`, `yarn` (except for MCP server installations)
- **RATIONALE**: Efficient disk usage, faster installs, better monorepo support
- **USAGE**:
  - `pnpm install` for installing dependencies
  - `pnpm add <package>` for adding packages
  - `pnpm run <script>` for running scripts

### Java Development
- **REQUIRED**: `sdkman` for JDK management
- **REQUIRED**: `maven` or `gradle` via sdkman for build systems
- **RATIONALE**: Version consistency, easy JDK switching
- **USAGE**:
  - `sdk install java <version>`
  - `sdk use java <version>`
  - `mvn` or `gradle` commands as appropriate

### Rust Development
- **REQUIRED**: `cargo` for all Rust operations
- **RATIONALE**: Standard Rust toolchain
- **USAGE**:
  - `cargo build` for building
  - `cargo run` for running
  - `cargo test` for testing

## Repository Standards

### Required Files
Every repository MUST contain:
- `DEVELOPMENT_RULES.md` (this file)
- `.zshrc` or shell configuration hints
- Language-specific configuration files following the tool requirements above

### Configuration Files
- Python: `pyproject.toml` with `uv` configuration
- Node.js: `package.json` with `pnpm` configuration
- Java: `pom.xml` or `build.gradle` via sdkman tools
- Rust: `Cargo.toml`

### Documentation Requirements
- All README files must include tool-specific setup instructions
- Scripts must be written for ZSH compatibility
- Examples must use the required tooling

## Enforcement

### For Developers
- All pull requests will be checked for compliance
- CI/CD pipelines will enforce these tool requirements
- Local development setup scripts must use these tools

### For AI/Automation Systems
- Claude Code configurations must use these tools
- MCP servers must follow these patterns
- All generated scripts and configurations must comply

## Migration Strategy

### Existing Repositories
1. Update package managers to required tools
2. Add/update configuration files
3. Update documentation and scripts
4. Test all workflows with new tools
5. Commit and push changes

### New Repositories
- Must start with compliant tooling from day one
- Use provided templates and examples
- Follow established patterns

## Compliance Verification

Run these commands to verify compliance:

```zsh
# Check tools are installed
which uv uvx pnpm cargo
sdk version

# Check configurations exist
ls -la pyproject.toml package.json Cargo.toml pom.xml build.gradle 2>/dev/null

# Test basic operations
uv --version
pnpm --version
cargo --version
```

## Support

For questions or issues with these requirements:
1. Check tool documentation
2. Review existing compliant repositories
3. Create an issue in the main orchestrator repository

---

**ENFORCEMENT LEVEL**: MANDATORY
**LAST UPDATED**: 2025-09-28
**APPLIES TO**: All repositories, all developers, all AI systems