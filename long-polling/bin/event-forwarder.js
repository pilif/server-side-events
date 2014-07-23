#!/usr/bin/env node

/*
  invoke with the path to the config file as the first and only argument.
  when querying using HTTP (on port 9984), use the following interfacve:

  /<channel>[/<waitkey>][?last_event_id=<last_event_id>|req-<request-id>]

  channel: the channel you are listeing to
  waitkey: an arbitrary key to force shortpolling if we are already
           waiting on this
  last_event_id: Either of:
     - the ID of the last event we have received processed
     - req- followed by the ID of the current request

  last_event_id is mandatory, but instead of the query-string, we also accept
  the HTML5 EventSource request header "Last-Event-ID"

  If there are any events to play back since last_event_id, the connection
  will immediately return a JSON array of all events so far.

  If there are no events to play back since last_event_id and there is no
  connection with <waitkey> waiting, the HTTP connection will wait until
  there's a redis PUBLISH event on channel:<channel> at which point the
  connection will return a JSON array of all events queued up since
  last_event_id

  If there are no events to play back since last_event_id and there is
  already a connection waiting on <waitkey>, the HTTP connection will
  immediately return []
*/

require('coffee-script/register');
require('../lib/server').run();
