# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

BrickPack (`rbx-brickpack`) is a Roblox instance serializer library written in Luau. It serializes/deserializes Roblox `Instance` trees into a compact binary format. The project is currently mid-rewrite.

### Toolchain

The project uses two toolchain managers:
- **Rokit** (`rokit.toml`): installs **Lune** (0.10.4) and **Darklua** (0.17.3)
- **Aftman** (`aftman.toml`): defines **Rojo** (7.7.0-rc.1), but Rojo is also installed via Rokit in the cloud environment

All tools live in `~/.rokit/bin`. The `pesde` package manager (Luau ecosystem) is installed at `/usr/local/bin/pesde`.

### Build pipeline

The full build pipeline is:
1. `pesde install` — install Luau packages (currently none declared)
2. `lune run scripts/InstallPackages` — runs pesde install and reorganizes package directories
3. `rojo sourcemap default.project.json -o sourcemap.json` — generate Rojo sourcemap
4. `lune run scripts/ConvertRequires` — converts path-based `require()` calls to Roblox-style using darklua (modifies source files in-place; revert with `git checkout` if needed)
5. `rojo serve` — serves the project for Roblox Studio to connect to

### Testing

Tests use **TestEZ** (vendored in `tests/testez/`) and run **inside Roblox Studio only**. There is no headless test runner. The test entry point is `RunTests.server.luau`. Running tests requires:
1. `rojo serve` running locally
2. Roblox Studio connected to the Rojo server
3. Studio executes `RunTests.server.luau` as a ServerScript

This means **tests cannot be run in the cloud VM** (Roblox Studio is Windows/macOS only).

### Linting / type checking

No linting tools (selene, stylua) are configured in the project. `luau-lsp analyze` can be run for type checking, but produces many false-positive "Unknown type" errors for Roblox-specific globals (`Instance`, `Vector3`, `CFrame`, etc.) and `@self`-aliased requires that only resolve in-IDE:

```
luau-lsp analyze --sourcemap=sourcemap.json src/
```

### pesde on headless Linux

`pesde` requires `gnome-keyring` and a D-Bus session. The cloud VM has these set up in `~/.bashrc`. If pesde fails with "Secret Service: no result found", ensure dbus and gnome-keyring-daemon are running:
```bash
eval "$(dbus-launch --sh-syntax)"
echo "" | gnome-keyring-daemon --unlock 2>/dev/null
```
