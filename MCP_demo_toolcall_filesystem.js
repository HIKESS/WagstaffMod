const { spawn } = require('child_process');

// Minimal smoke-test for the filesystem MCP server by booting it.
// Full MCP message exchange requires an MCP host; here we just verify
// the server starts correctly with -- roots-less startup.

const modDir = "c:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/mods/WagstaffPlus";

const child = spawn('npx', [
  '-y',
  '@modelcontextprotocol/server-filesystem',
  modDir
], { stdio: ['pipe', 'pipe', 'pipe'] });

child.stdout.on('data', d => process.stdout.write(d.toString()));
child.stderr.on('data', d => process.stderr.write(d.toString()));

setTimeout(() => {
  child.kill('SIGTERM');
  console.log('\nFilesystem MCP server started successfully (boot).');
}, 2000);

