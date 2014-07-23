/*
  This is compiled from Coffee-Script. The source is done in coffee
  and being dynamically compiled by our frontend infrastructure.

  For the demo though, I don't want to set up all of that, which is why
  I'm just using the compiled file here.

  It's readable-ish enough and the talk itself will be showing
  the coffee source of this (the poll function), so it should be clear
  what's going on.
*/
(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  EventChannelLongPoll = (function() {
    function EventChannelLongPoll(channel, request_time, wait_id) {
      this.channel = channel;
      this.request_time = request_time;
      this.wait_id = wait_id;
      this.poll = __bind(this.poll, this);
      this.enabled = false;
      this.use_proxy = false;
      this.last_event_id = "rt-" + this.request_time;
      this.endpoint = '/events';
      if (!this.endpoint) {
        throw "event server url not configured";
      }
    }

    EventChannelLongPoll.prototype.setEnabled = function(s) {
      if (!this.enabled && s) {
        this.poll();
      }
      return this.enabled = s;
    };

    EventChannelLongPoll.prototype.poll = function() {
      var p, url,
        _this = this;
      p = this.use_proxy ? '?proxy=1' : '';
      url = this.endpoint + "/" + this.channel + "/" + this.wait_id + p;
      return $.ajax(url, {
        cache: false,
        dataType: 'json',
        headers: {
          'Last-Event-Id': this.last_event_id
        },
        success: function(data, s, xhr) {
          var reconnect_in;
          if (!_this.enabled) {
            return;
          }
          _this.fireAll(data);
          reconnect_in = parseInt(xhr.getResponseHeader('x-ps-reconnect-in'), 10);
          if (!(reconnect_in >= 0)) {
            reconnect_in = 10;
          }

          if (_this.enabled) {
            return setTimeout(_this.poll, reconnect_in * 1000);
          }
        },
        error: function(xhr, textStatus, error) {
          var rc, _ref;
          if (!_this.enabled) {
            return;
          }
          rc = ((_ref = xhr.status) === 504 || _ref === 12002) || (textStatus === 'timeout') ? 0 : 10000;
          if (_this.enabled) {
            return setTimeout(_this.poll, rc);
          }
        }
      });
    };

    EventChannelLongPoll.prototype.fireAll = function(events) {
      var _this = this;
      if (!(events && events.length)) {
        return;
      }
      return _.each(events, function(evt) {
        if (evt.id) {
          _this.last_event_id = evt.id;
        }
        return _this.fire(evt.data);
      });
    };

    EventChannelLongPoll.prototype.fire = function(evt) {
      $(this).trigger(evt.type, evt.data);
      return $(this).trigger('_all', evt);
    };

    return EventChannelLongPoll;

  })();

}).call(this);
