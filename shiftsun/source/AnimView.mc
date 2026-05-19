using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class AnimView extends WatchUi.View {

    private const CCX    = 144;
    private const CCY    = 31;
    private const CCR    = 27;
    private const FRAMES = 8;

    private var _frame = 0;
    private var _timer = null;
    private var _bg    = null;

    function initialize() {
        View.initialize();
    }

    function onShow() {
        _bg = WatchUi.loadResource(Rez.Drawables.AnimBg);
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 500, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTimer() as Void {
        _frame = (_frame + 1) % FRAMES;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        // Static background bitmap
        if (_bg != null) {
            dc.drawBitmap(0, 0, _bg);
        }

        _drawFireworks(dc, _frame);
        _drawCountdown(dc);
        _drawTimeCircle(dc);
    }

    private function _drawFireworks(dc as Graphics.Dc, frame) as Void {
        // White bursts in window area (x≈10..150, y≈10..80) on dark bitmap sky
        // 3 burst positions, each lives 2 frames: small (size=6) → large (size=12)
        // frame 0,7: dark pause
        // frame 1,2: burst A at (58, 32)
        // frame 3,4: burst B at (95, 22)
        // frame 5,6: burst C at (125, 38)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        if (frame == 1) { _drawBurst(dc, 58, 32, 6); }
        if (frame == 2) { _drawBurst(dc, 58, 32, 12); }
        if (frame == 3) { _drawBurst(dc, 95, 22, 6); }
        if (frame == 4) { _drawBurst(dc, 95, 22, 12); }
        if (frame == 5) { _drawBurst(dc, 125, 38, 6); }
        if (frame == 6) { _drawBurst(dc, 125, 38, 12); }
    }

    private function _drawBurst(dc, cx, cy, size) {
        dc.drawLine(cx, cy, cx,        cy - size);
        dc.drawLine(cx, cy, cx + size, cy - size / 2);
        dc.drawLine(cx, cy, cx + size, cy);
        dc.drawLine(cx, cy, cx + size, cy + size / 2);
        dc.drawLine(cx, cy, cx,        cy + size);
        dc.drawLine(cx, cy, cx - size, cy + size / 2);
        dc.drawLine(cx, cy, cx - size, cy);
        dc.drawLine(cx, cy, cx - size, cy - size / 2);
    }

    private function _drawCountdown(dc as Graphics.Dc) as Void {
        var rem = WatchSchedule.voyageRemainingSec().toNumber();
        if (rem < 0) { rem = 0; }

        var w = rem / 604800;
        var d = rem / 86400;
        var h = rem / 3600;
        var m = rem / 60;
        var s = rem;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(4, 38,  Graphics.FONT_SMALL, w.toString() + "w", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 57,  Graphics.FONT_SMALL, d.toString() + "d", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 76,  Graphics.FONT_SMALL, h.toString() + "h", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 95,  Graphics.FONT_SMALL, m.toString() + "m", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(4, 114, Graphics.FONT_SMALL, s.toString() + "s", Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function _drawTimeCircle(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(CCX, CCY, 31);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawCircle(CCX, CCY, CCR);
        _drawMoon(dc);
    }

    private function _drawMoon(dc as Graphics.Dc) as Void {
        dc.fillCircle(CCX, CCY, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(CCX + 5, CCY - 3, 8);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
    }
}

class AnimDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() {
        WatchUi.switchToView(new MainView(), new WatchTrackerDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() {
        WatchUi.switchToView(new DetailsView(), new DetailsDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }
}
