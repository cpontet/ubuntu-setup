#!/bin/bash

claude mcp add memory npx @modelcontextprotocol/server-memory -s user
claude mcp add filesystem npx "-y", "@modelcontextprotocol/server-filesystem", "/home/cpontet/repos" -s user
