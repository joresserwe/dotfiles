const { mapkey, Hints } = api;

const HOVER_KEEP_ALIVE_MS = 8000;
const HOVER_TICK_MS = 700;

// Surfingkeys has no native hover command, so synthetic pointer events are dispatched.
// A leave/out pair is sent first each run: players track "cursor still inside" and ignore a
// repeat enter, so re-entering only re-reveals controls after this reset. Coordinates are the
// element center because some players gate control visibility on real pointer position.
mapkey(';h', 'Hover over an element', function () {
    Hints.create('*', function (element) {
        const rect = element.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const fire = function (type, dx) {
            const at = { clientX: cx + dx, clientY: cy };
            element.dispatchEvent(
                new MouseEvent(type, { view: window, bubbles: true, cancelable: true, ...at })
            );
            element.dispatchEvent(
                new PointerEvent(type.replace('mouse', 'pointer'), {
                    view: window, bubbles: true, cancelable: true, pointerType: 'mouse', ...at,
                })
            );
        };
        ['mouseout', 'mouseleave'].forEach(function (t) { fire(t, 0); });
        ['mouseover', 'mouseenter', 'mousemove'].forEach(function (t) { fire(t, 0); });

        // Players auto-hide controls after a few idle seconds, so nudge mousemove until the
        // keep-alive window elapses. The x coordinate alternates by 1px because some players
        // ignore a mousemove whose position is identical to the previous one.
        let elapsed = 0;
        const id = setInterval(function () {
            elapsed += HOVER_TICK_MS;
            fire('mousemove', elapsed % (2 * HOVER_TICK_MS) ? 1 : -1);
            if (elapsed >= HOVER_KEEP_ALIVE_MS) clearInterval(id);
        }, HOVER_TICK_MS);
    });
});
