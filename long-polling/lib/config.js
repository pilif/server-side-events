var fs = require('fs');
var cfgfile = process.env['FORWARDER_CONFIG'];

if (!cfgfile || !fs.existsSync(cfgfile)){
  console.error("config file missing (FORWARDER_CONFIG)")
  process.exit(1);
}

exports.config = JSON.parse(fs.readFileSync(cfgfile));
