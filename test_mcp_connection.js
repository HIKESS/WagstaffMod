const fs = require('fs');
const path = 'c:/Users/edcfa/AppData/Roaming/Code/User/globalStorage/blackboxapp.blackboxagent/settings/blackbox_mcp_settings.json';
const raw = fs.readFileSync(path,'utf8');
console.log('raw length', raw.length);
JSON.parse(raw);
console.log('json ok');

