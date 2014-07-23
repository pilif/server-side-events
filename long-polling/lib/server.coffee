
cfg = require('./config').config

if not cfg['psql-access-string']
  console.error "need postgres access string"
  process.exit 1

http = require 'http'
redis = require 'redis'
pg = require("pg").native
pg.defaults.poolSize = 5

ok = (res, headers)->
  h = 'Content-Type': 'application/json'
  for own k, v of headers
    h[k] = v
  res.writeHead 200, h

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

with_postgres = (db, cb)->
  as = cfg['psql-access-string']
  as = as + db if db
  pg.connect as, (err, client)->
    cb(err, client)

query = (db, query, params, cb)->
  with_postgres db, (err, client)->
    return cb(err, null) if err
    client.query query, params, (err, res)->
      return cb(err, null) if err
      cb(null, res.rows.map expand_events)
      client.end()


events_since_id = (db, channel, id, cb)->
  q = """
      select * from events
      where channel_id = $1 and id > $2
      order by id asc
      """
  query db, q, [channel, id], cb

events_since_time = (db, channel, ts, cb)->
  q = """
      select * from events o
      where channel_id = $1
      and ts > (SELECT TIMESTAMP WITH TIME ZONE 'epoch' + $2 * INTERVAL '1 second')
      order by id asc
      """
  query db, q, [channel, ts], cb

waiting_channels = {}
listen_port = cfg.listen_port ? 9984
listen_address = cfg.listen_address ? '120.0.0.1'

exports.run = ->
  http.createServer((req, res)->
    return notfound res if req.url == '/favicon.ico'

    url = require("url").parse req.url, true
    [channel, wkey] = url.pathname.substr(1).split '/'
    last_event_id = req.headers['last-event-id'] or url.query['last_event_id']
    db = null
    if (cfg['dynamic-database'])
      db = req.headers['ps-dynamic-database'] ? 'popscan'
      wkey = db + wkey

    return http_error res, 400, 'missing last-event-id' unless last_event_id

    if last_event_id.substr(0, 3) == 'rt-'
      fun = events_since_time
      last_event_id = last_event_id.substr(3)
    else
      fun = events_since_id

    clear_waiting = ()->
      delete waiting_channels[wkey] if wkey

    set_waiting = ()->
      waiting_channels[wkey] = true if wkey

    waiting = ()->
      wkey and waiting_channels[wkey]

    req.on 'close', ->
      clear_waiting()

    fun db, channel, last_event_id, (err, evts)->
      return http_error res, 500, 'Failed to get event data: ' + err if err

      if waiting() or (evts and evts.length > 0)
        ok res,
          'x-shortpoll-info': 'true'
          'x-ps-reconnect-in': if waiting() then 5 else 0
        return res.end JSON.stringify evts

      c = redis.createClient 6379, cfg['redis-server'] || 'localhost'
      req.on 'close', ->
        c.end()
      c.select cfg['db'] || 2, (err, r)->
        set_waiting()
        c.subscribe 'channels:'+channel
        c.on "message", (chn, message)->
          fun db, channel, last_event_id, (err, evts)->
            c.end()
            return http_error 500, 'Failed to get event data' if err
            ok res,
              'x-shortpoll-info': 'false'
              'x-ps-reconnect-in': 0
            res.end JSON.stringify evts
            clear_waiting()
  ).listen listen_port, listen_address

  console.log "Server running at http://#{listen_address}:#{listen_port}/"
