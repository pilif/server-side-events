#!/usr/bin/env node
var sys = require('sys');

var redis = require('redis');
var pg = require("pg").native;

pg.defaults.poolSize = 2


var cheese_types = ['Emmentaler', 'Appenzeller', 'Gruyère',
    'Vacherin', 'Sprinz'];


function create_cheese(){
    return {
      pieces: Math.floor(Math.random() * 115) + 5,
      cheese_type:
        cheese_types[Math.floor(Math.random()*cheese_types.length)]
    }
}


var cheese_delivery = create_cheese();
publish(cheese_delivery);



function publish(cheese_delivery){
  var cheese_event = {type: 'cheese_created', data: cheese_delivery};
  query(
    "insert into events (channel_id, data) values ($1, $2)",
    ['cheese', JSON.stringify(cheese_event)],
    function(err, rows){
      redis_publish('cheese', cheese_event, function(err, res){
        console.log(
          "Created " + cheese_delivery.pieces + " pieces of " + cheese_delivery.cheese_type
        );
      })
    }
  );
}

function with_postgres(cb){
  pg.connect('postgres://pilif@localhost/cheese', function(err, client){
    cb(err, client);
  });
}

function query(query, params, cb){
  with_postgres(function(err, client){
    if (err) return cb(err, null);
    client.query(query, params, function(err, res){
      if (err) return cb(err, null);
      cb(null, res.rows);
      client.end();
    });
  });
}

function with_redis(cb){
  var client = redis.createClient(6379, 'localhost');
  client.select(2, function(err, result){
    if (err) return cb(err, null);
    cb(null, client);
  })
}

function redis_publish(channel, data, cb){
  with_redis(function(err, client){
    if (err) return cb(err, null);
    client.publish('channels:cheese', JSON.stringify(data), function(err, result){
      client.end();
      cb(err, result);
    });
  });
}
