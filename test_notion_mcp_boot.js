const { spawn } = require('child_process');

// Boots the Notion MCP server in stdio mode (default) and reports that it starts.
// Note: Without an MCP client host transport, we only validate boot here.

// Use cmd.exe to resolve PATH inconsistencies in this environment.
const child = spawn('cmd', ['/c', 'npx -y @notionhq/notion-mcp-server'], {
  stdio: ['pipe', 'pipe', 'pipe'],
});


child.stdout.on('data', (d) => process.stdout.write(d.toString()));
child.stderr.on('data', (d) => process.stderr.write(d.toString()));

setTimeout(() => {
  try {
    child.kill('SIGTERM');
  } catch {}
  console.log('\nNotion MCP server started successfully (boot).');
}, 4000);

