
cfg = require('./config').config

if not cfg['psql-access-string']
  console.error "need postgres access string"
  process.exit 1

http = require 'http'
redis = require 'redis'
pg = require("pg").native
pg.defaults.poolSize = 5

ok = (res, headers)->
  for own k, v of headers
    res.setHeader k, v
  res.writeHead 200

notfound = (res)->
  res.writeHead 404, 'Content-Type:': 'text/plain'
  res.end 'not found'

http_error = (res, code, text)->
  res.writeHead code, 'Content-Type': 'text/plain'
  res.end text

tryparse = (i)->
  try
    JSON.parse(i)
  catch error
    i

expand_events = (e)->
  e.data = tryparse e.data
  e

with_postgres = (cb)->
  as = cfg['psql-access-string']
  pg.connect as, (err, client)->
    cb(err, client)

query = (query, params, cb)->
  with_postgres (err, client)->
    return cb(err, null) if err
    client.query query, params, (err, res)->
      return cb(err, null) if err
      cb(null, res.rows.map expand_events)
      client.end()


events_since_id = (channel, id, cb)->
  q = """
      select * from events
      where channel_id = $1 and id > $2
      order by id asc
      """
  query q, [channel, id], cb

events_since_time = (channel, ts, cb)->
  q = """
      select * from events o
      where channel_id = $1
      and ts > (SELECT TIMESTAMP WITH TIME ZONE 'epoch' + $2 * INTERVAL '1 second')
      order by id asc
      """
  query q, [channel, ts], cb


handler = (channel, last_event_id, cb)->
    if last_event_id.substr(0, 3) == 'rt-'
      last_event_id = last_event_id.substr(3)
      events_since_time(channel, last_event_id, cb)
    else
      events_since_id(channel, last_event_id, cb)

write_long_poll = (response, events, add_headers)->
  unless response.headersSent
    response.setHeader 'Content-Type', 'application/json'
    ok response, add_headers
  response.end JSON.stringify events
  false

write_eventsource = (response, events, add_headers)->
  unless response.headersSent
    response.setHeader 'Content-Type', 'text/event-stream'
    ok response, add_headers

  for event in events
    response.write ["event: "+event.data.type,
      "data: " + JSON.stringify(event.data.data),
      "id: " + event.id,
      "", ""].join "\n"

  true

waiting_channels = {}
listen_port = cfg.listen_port ? 9984
listen_address = cfg.listen_address ? '120.0.0.1'

exports.run = ->
  http.createServer((req, res)->
    return notfound res if req.url == '/favicon.ico'

    url = require("url").parse req.url, true
    [channel, wkey] = url.pathname.substr(1).split '/'
    last_event_id = req.headers['last-event-id'] or url.query['last_event_id']
    flavor = req.headers['flavor'] or url.query['flavor'] or 'long-poll'

    return http_error res, 400, 'unknown flavor' unless flavor in ['long-poll', 'eventsource']
    write = if flavor == "long-poll" then write_long_poll else write_eventsource

    clear_waiting = ()->
      delete waiting_channels[wkey] if wkey

    set_waiting = ()->
      waiting_channels[wkey] = true if wkey

    waiting = ()->
      wkey and waiting_channels[wkey]

    req.on 'close', ->
      clear_waiting()

    close_redis = (client)->
      client.close()


    handle_request = ()->

      handler channel, last_event_id, (err, evts)->

        return http_error res, 500, 'Failed to get event data: ' + err if err

        last_event_id = evts[evts.length-1].id if (evts and evts.length > 0)

        if waiting() or (evts and evts.length > 0)
          return unless write(res, evts,
            'x-shortpoll-info': 'true'
            'x-ps-reconnect-in': if waiting() then 5 else 0)

        c = redis.createClient 6379, cfg['redis-server'] || 'localhost'
        close_redis = ()-> c.end()

        req.on 'close', close_redis

        c.select cfg['db'] || 2, (err, r)->
          set_waiting()
          c.subscribe 'channels:'+channel
          c.on "message", (chn, message)->
            handler channel, last_event_id, (err, evts)->
              c.end()
              req.removeListener 'close', close_redis
              return http_error 500, 'Failed to get event data' if err

              continue_listening = write res, evts,
                'x-shortpoll-info': 'false'
                'x-ps-reconnect-in': 0
              return clear_waiting() unless continue_listening
              last_event_id = evts[evts.length-1].id if (evts and evts.length > 0)
              process.nextTick ()->
                handle_request()
    handle_request()
  ).listen listen_port, listen_address

  console.log "Server running at http://#{listen_address}:#{listen_port}/"
