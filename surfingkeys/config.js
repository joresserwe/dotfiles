const { mapkey, Hints } = api;

// Surfingkeys has no native hover command, so synthetic pointer events are dispatched.
// No mouseout is sent, so revealed controls stay visible until a real cursor move or click.
mapkey(';h', 'Hover over an element', function () {
    Hints.create('*', function (element) {
        ['mouseover', 'mouseenter', 'mousemove'].forEach(function (type) {
            element.dispatchEvent(
                new MouseEvent(type, { view: window, bubbles: true, cancelable: true })
            );
        });
    });
});
