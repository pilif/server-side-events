#!/usr/bin/env node
var http = require('http');
var serveStatic = require('serve-static');
var httpProxy = require('http-proxy');
var finalhandler = require('finalhandler')

var serve = serveStatic('htdocs', {'index': ['index.html']});

var proxy = httpProxy.createProxyServer({
    target: 'http://localhost:9984'
});

var server = http.createServer(function(req, res){
  if (req.url.match(/^\/events/)){
    req.url = req.url.substr(7);
    return proxy.web(req, res, function(err, proxy_result){
        if (err){
            res.writeHead(504, {'Content-Type:': 'text/plain'});
            res.end('proxy error');
        }
    });
  }
  serve(req, res, finalhandler(req, res));
})

// Listen
server.listen(3000);
