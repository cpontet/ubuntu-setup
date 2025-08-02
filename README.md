# Ubuntu Dev Environment Setup

Basic setup of Ubuntu dev environment

## Setup environment

Run the script

```sh
git clone  https://github.com/cpontet/ubuntu-setup.git
cd ubuntu-setup
./setup.sh
```

## Configure Claude Code MCP Servers

- Copy `.mcp` to your home directory

  ```sh
  cp .mcp ~
  ```

- In `~/.mcp/strapi-mcp-server.config.json`, replace `<your-strapi-url>` and `<your-strapi-api-token>` by acutal values

- Copy the content of `.claude.mcp.json` and replace the `mcpServers` section in `~/.claude.json`.

- Test by running this command:

  ```sh
  claude mcp list
  ```

  It should give you this following output

  ```sh
  Checking MCP server health...

  filesystem: npx -y @modelcontextprotocol/server-filesystem /home/cpontet/repos - ✓ Connected
  convex: npx -y convex@latest mcp start - ✓ Connected
  strapi: npx -y @bschauer/strapi-mcp-server@2.6.0 - ✓ Connected
  memory: npx -y @modelcontextprotocol/server-memory - ✓ Connected
  ```
