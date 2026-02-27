parentBridge = {
    dispatchToParent: function(jsonStr) {
        try {
            if (window.parent && window.parent !== window) {
                if (typeof window.parent.dispatchSolarEvent === "function") {
                    var eventData = JSON.parse(jsonStr);
                    window.parent.dispatchSolarEvent(eventData);
                }
            } else if (typeof window.dispatchSolarEvent === "function") {
                var eventData = JSON.parse(jsonStr);
                window.dispatchSolarEvent(eventData);
            }
        } catch (e) {
            console.error("parentBridge.dispatchToParent error:", e);
        }
    }
};
