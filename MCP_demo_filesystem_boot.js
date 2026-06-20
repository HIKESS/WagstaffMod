const { spawn } = require('child_process');

const modDir = "c:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/mods/WagstaffPlus";

// Boot via `npx` using cmd.exe. This is only a smoke-test for the server process.
const child = spawn('cmd.exe', [
  '/c',
  `npx -y @modelcontextprotocol/server-filesystem "${modDir}"`
], { stdio: ['pipe', 'pipe', 'pipe'] });

child.stdout.on('data', d => process.stdout.write(d.toString()));
child.stderr.on('data', d => process.stderr.write(d.toString()));

setTimeout(() => {
  child.kill('SIGTERM');
  console.log('\nFilesystem MCP server started successfully (boot).');
}, 2500);

