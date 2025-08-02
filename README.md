# ubuntu-setup

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

- Copy the content of `.claude.mcp.json` and replace the `mcpServers` section in `~/.claude.json`
