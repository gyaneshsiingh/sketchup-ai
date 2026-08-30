# SketchUp MCP

Two ways to drive SketchUp over MCP (Model Context Protocol):

## 1. HTTP (streamable-HTTP transport)

When SketchUp is running with the plugin loaded, start the server via
**Extensions → OpenCode Studio → Start MCP Server** (default port `8723`,
binds to `127.0.0.1` only, token-authenticated).

- Endpoint: `http://127.0.0.1:8723/mcp` (JSON-RPC 2.0, POST)
- Health: `GET http://127.0.0.1:8723/health`
- Token: `~/Library/Application Support/OpenCodeStudio/config.json` → `mcp_token`
  (Windows: `%APPDATA%\OpenCodeStudio\config.json`)
- Tools: the full built-in skill set (rooms, walls with openings, furniture
  kit, auto-layout, palettes, editing) is exposed via `tools/list`.

The plugin itself can also consume this server: add to the plugin's
`config.json` → `"mcp_servers"`:

```json
{ "name": "sketchup", "url": "http://127.0.0.1:8723/mcp",
  "headers": { "Authorization": "Bearer <mcp_token>" } }
```

## 2. stdio (opencode / Claude Desktop / any stdio MCP client)

Run the bridge:

```bash
SKETCHUP_MCP_TOKEN=<mcp_token> ruby mcp/stdio_proxy.rb
```

opencode.json:

```json
{
  "mcp": {
    "sketchup": {
      "type": "local",
      "command": ["ruby", "/path/to/sketchup-plugin/mcp/stdio_proxy.rb"],
      "environment": { "SKETCHUP_MCP_TOKEN": "<mcp_token>" }
    }
  }
}
```

Then ask your agent: *"Build a 4x5 living room and apply the scandinavian
palette"* — it will call `create_room`, `auto_layout`, `style_palette`, …
inside SketchUp.

## Security

The server listens on loopback only and requires a bearer token by default.
Anyone with the token can modify the open SketchUp model — treat it like a
password.
