# OpenCode Studio — AI Design Automation for SketchUp

A SketchUp plugin that turns plain-language tasks into real geometry. It asks
for your **OpenCode API key**, then runs an **agentic tool-calling loop**
against any OpenAI-compatible endpoint (default: `https://opencode.ai/zen/v1`)
to build rooms, place furniture, and apply materials — plus a built-in
**SketchUp MCP server** so any MCP client (opencode, Claude Desktop, …) can
drive SketchUp too.

## What's in the skill set (v1.1)

- **Structure**: `create_room`, `create_wall` (with door/window openings), `set_units`, `add_tag`
- **Furniture kit**: `create_bed`, `create_sofa`, `create_table`, `create_wardrobe`, `create_tv_unit`, `place_component`, `create_box`
- **Auto-layout**: `auto_layout` — one call furnishes a bedroom / living / dining room heuristically (clearances, wall alignment)
- **Makeovers**: `style_palette` — scandinavian / industrial / luxury / bohemian / minimalist
- **Editing**: `duplicate_object`, `resize_group`, `move_group`, `rotate_group`, `select_by_name`, `delete_selection`, `apply_color`
- **Introspection**: `query_scene`, `list_components`, `zoom_extents`

## Install

1. Run `./build.sh` (creates `dist/opencode_studio.rbz`).
2. In SketchUp: **Extensions → Extension Manager → Install Extension…**
3. Pick the `.rbz`. A new *Extensions → OpenCode Studio → Open Panel* menu and
   toolbar button appear.
4. Click ⚙ in the panel, paste your **OpenCode API key**, pick a model
   (↻ fetches the list), **Save & Connect**.

## Use

Type tasks like:

- “Build a 4 m × 5 m living room with 2.7 m ceilings, warm white walls.”
- “Place a sofa against the north wall and a coffee table in the middle.”
- “Inspect the model and list the groups.”

The agent plans, calls tools (`create_room`, `place_component`, `create_box`,
`apply_color`, …), executes them in SketchUp on the main thread (each step is
a proper undo-able operation), and reports progress in the panel. **Stop**
interrupts the loop; ⌘/Ctrl+Enter sends.

## SketchUp MCP server

The plugin starts a local MCP server (loopback only, token-authenticated —
see **mcp/README.md** for client configs):

- Endpoint `http://127.0.0.1:8723/mcp` (JSON-RPC, streamable-HTTP)
- `GET /health`, `tools/list` exposes the entire skill set above
- Start/stop via **Extensions → OpenCode Studio** menu; token in `config.json` → `mcp_token`
- stdio bridge for opencode/Claude: `mcp/stdio_proxy.rb`

```
┌─ opencode / Claude ─┐   stdio   ┌─────────────────────────────┐
│  any MCP client  ───┼──────────▶│ mcp/stdio_proxy.rb          │
└─────────────────────┘           └──────────┬──────────────────┘
                                             │ HTTP 127.0.0.1:8723
┌─ SketchUp (Ruby, main thread) ──────────────▼───────────────┐
│ McpServer ⇄ DesignTools + FurnitureTools (skills)           │
│ Agent loop ⇄ HTML panel  ⇄ ApiClient (background thread)    │
└──────────────│──────────────────────────────────────────────┘
               ▼
   OpenAI-compatible API (OpenCode Zen) + optional remote MCP servers
```

- **Skills** live in `opencode_studio/design_tools.rb` and
  `opencode_studio/furniture_tools.rb` — coordinates in meters, origin at room
  corner. Add your own by appending to `DEFINITIONS` and adding a method of
  the same name.
- **Remote MCP**: add servers to the plugin's `config.json`:
  ```json
  { "mcp_servers": [ { "name": "my-tools", "url": "https://my-mcp.example.com/mcp", "headers": { "Authorization": "Bearer …" } } ] }
  ```
  Their tools merge into the agent automatically.

## Development

- `./build.sh` — syntax-checks all Ruby files and rebuilds the `.rbz`
- `ruby test/smoke.rb` — runs pure-Ruby tests (no SketchUp needed)
- Plugin folder (unpacked dev install):
  `~/Library/Application Support/SketchUp 20XX/SketchUp/Plugins/`
- Your API key is stored locally (`~/Library/Application Support/OpenCodeStudio/config.json`,
  chmod 600). It is sent only to the base URL you configure.

## Notes & limits

- Runtime behavior must be verified inside SketchUp (this repo builds it
  without SketchUp installed; `build.sh` checks syntax, `smoke.rb` tests logic).
- `place_component` searches components already loaded in the model and falls
  back to a placeholder box.
- MCP servers must support JSON-RPC POST (JSON or SSE replies).
