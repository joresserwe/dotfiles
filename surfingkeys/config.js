const { mapkey, Hints } = api;

// Surfingkeys has no native hover command, so synthetic pointer events are dispatched.
// A leave/out pair is sent first each run: players track "cursor still inside" and ignore a
// repeat enter, so re-entering only re-reveals controls after this reset. Coordinates are the
// element center because some players gate control visibility on real pointer position.
mapkey(';h', 'Hover over an element', function () {
    Hints.create('*', function (element) {
        const rect = element.getBoundingClientRect();
        const at = { clientX: rect.left + rect.width / 2, clientY: rect.top + rect.height / 2 };
        const fire = function (type) {
            element.dispatchEvent(
                new MouseEvent(type, { view: window, bubbles: true, cancelable: true, ...at })
            );
            element.dispatchEvent(
                new PointerEvent(type.replace('mouse', 'pointer'), {
                    view: window, bubbles: true, cancelable: true, pointerType: 'mouse', ...at,
                })
            );
        };
        ['mouseout', 'mouseleave'].forEach(fire);
        ['mouseover', 'mouseenter', 'mousemove'].forEach(fire);
    });
});
