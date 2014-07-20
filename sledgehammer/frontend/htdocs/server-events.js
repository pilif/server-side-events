(function(window){
    window.EventChannel = function(){
        var socket = new WebSocket("ws://localhost:8080/");
        var self = this;
        socket.onmessage = function(evt){
            var event_info = JSON.parse(evt.data);
            var evt = jQuery.Event(event_info.type, event_info.data);
            $(self).trigger(evt);
        }
    }
})(window);
