#!/usr/bin/env node
var WebSocketServer = require('ws').Server;
var redis = require('redis');


var wss = new WebSocketServer({port: 8080});
wss.on('connection', function(ws) {
  var client = redis.createClient(6379, 'localhost');
  ws.on('close', function(){
    console.log("disconnecting");
    client.end();
  });
  client.select(2, function(err, result){
    if (err) {
      console.log("Failed to set redis database");
      return;
    }
    client.subscribe('channels:cheese');
    client.on('message', function(chn, message){
      console.log("Got "+message+ " on " + chn);
      ws.send(message);
    });
  })
});


function with_redis(cb){
  var client = redis.createClient(6379, 'localhost');
  client.select(2, function(err, result){
    if (err) return cb(err, null);
    cb(null, client);
  })
}
