// A poyfill for requestIdleCallback.
//
// For: IE 11, Edge, and Firefox
// Source: https://www.npmjs.com/package/requestidlecallback-polyfill
// https://developer.mozilla.org/en-US/docs/Web/API/Window/requestIdleCallback
window.requestIdleCallback =
    window.requestIdleCallback ||
    function(cb) {
        var start = Date.now();
        return setTimeout(function() {
            cb({
                didTimeout: false,
                timeRemaining: function() {
                    return Math.max(0, 50 - (Date.now() - start));
                },
            });
        }, 1);
    };

window.cancelIdleCallback =
    window.cancelIdleCallback ||
    function(id) {
        clearTimeout(id);
    };
