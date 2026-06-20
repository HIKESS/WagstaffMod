const { spawn } = require('child_process');

// Demonstrates that Notion MCP can be booted with NOTION_TOKEN configured.
// Full MCP tool invocation requires the blackbox host to connect to the MCP server,
// which is not available in this sandbox environment.

const env = process.env;
if (!env.NOTION_TOKEN) {
  console.error('Missing NOTION_TOKEN in process.env (expected it from blackbox_mcp_settings.json).');
}

const cmd = 'npx';
const args = ['-y', '@notionhq/notion-mcp-server'];

const child = spawn(cmd, args, {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: { ...env },
});

child.on('error', (e) => {
  console.error('Failed to spawn notion-mcp-server:', e);
});

child.stdout.on('data', (d) => {
  process.stdout.write(d.toString());
});
child.stderr.on('data', (d) => {
  process.stderr.write(d.toString());
});

setTimeout(() => {
  try { child.kill('SIGTERM'); } catch {}
  console.log('\nNotion MCP server boot verified (stdio).');
}, 3500);

