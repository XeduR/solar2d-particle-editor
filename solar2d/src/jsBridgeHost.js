jsBridgeHost = {
    _queue: [],

    // Called from Lua to get next pending command (returns JSON string or empty string)
    dequeue: function() {
        if ( jsBridgeHost._queue.length === 0 ) {
            return "";
        }
        var cmd = jsBridgeHost._queue.shift();
        return JSON.stringify( cmd );
    },

    // Called from Lua to check if queue has items (returns 1 or 0 for Lua compatibility)
    hasPending: function() {
        return jsBridgeHost._queue.length > 0 ? 1 : 0;
    }
};

window.addEventListener( "message", function( event ) {
    if ( event.data && event.data.type === "callLua" ) {
        jsBridgeHost._queue.push( {
            id: event.data.id || null,
            method: event.data.method,
            args: event.data.args
        } );
    }
}, false );
