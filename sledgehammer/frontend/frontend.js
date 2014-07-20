#!/usr/bin/env node
var http = require('http');
var serveStatic = require('serve-static');
var finalhandler = require('finalhandler')

// Serve up public/ftp folder
var serve = serveStatic('htdocs', {'index': ['index.html']});

// Create server
var server = http.createServer(function(req, res){
  serve(req, res, finalhandler(req, res));
})

// Listen
server.listen(3000);
