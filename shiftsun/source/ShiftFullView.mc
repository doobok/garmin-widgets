using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Lang;

class MainView extends WatchUi.View {

    private const CX    = 88;
    private const CY    = 90;
    private const R_OUT = 65;
    private const R_IN  = 57;

    // Secondary round display: cx=144, cy=31, r=31 (separate LCD, cut from main octagon)
    private const CCX = 144;
    private const CCY = 31;
    private const CCR = 27;

    private var _isOnDuty   = true;
    private var _blockPct   = 0;
    private var _totalPct   = 0;
    private var _remaining  = "--";
    private var _isPending  = false;
    private var _isInvalid  = false;
    private var _timer      = null;

    function initialize() {
        View.initialize();
    }

    function onShow() {
        try {
            WatchSchedule.loadConfig();
            _updateState();
        } catch (ex instanceof Lang.Exception) {
            _isInvalid = true;
        }
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 60000, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        try {
            _updateState();
        } catch (ex instanceof Lang.Exception) {
            _isInvalid = true;
        }
        WatchUi.requestUpdate();
    }

    private function _updateState() {
        _totalPct  = WatchSchedule.totalProgress();
        if (WatchSchedule.isPending()) {
            _isPending = true;
            _remaining = WatchSchedule.formatMinutes(WatchSchedule.minutesUntilStart());
        } else {
            _isPending = false;
            _isOnDuty  = WatchSchedule.isOnDuty();
            _blockPct  = WatchSchedule.blockProgress();
            _remaining = WatchSchedule.formatMinutes(WatchSchedule.blockRemaining());
        }
        _isInvalid = false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        if (_isInvalid) {
            dc.drawText(CX, 80, Graphics.FONT_SMALL, "Invalid", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_isPending) {
            _drawPending(dc);
        } else {
            _drawActive(dc);
        }

        // Always last — overwrites any main-arc bleed into secondary display area
        _drawTotalCircle(dc);
    }

    private function _drawActive(dc as Graphics.Dc) as Void {
        // Background arc: thin outline, 270°, opens at bottom
        dc.drawArc(CX, CY, R_OUT, Graphics.ARC_CLOCKWISE, 225, 315);

        // Progress arc: thick (R_IN..R_OUT), 225° clockwise by pct*270/100°
        if (_blockPct > 0) {
            var endDeg = ((225 - _blockPct * 270 / 100) + 360) % 360;
            var r;
            for (r = R_IN; r <= R_OUT; r++) {
                dc.drawArc(CX, CY, r, Graphics.ARC_CLOCKWISE, 225, endDeg);
            }
        }

        dc.drawText(CX, 62, Graphics.FONT_MEDIUM, _remaining, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX, 94, Graphics.FONT_XTINY, "remaining", Graphics.TEXT_JUSTIFY_CENTER);

        // State label sits in the arc gap below the endpoints (arc ends ~y=136)
        var label = _isOnDuty ? "ON DUTY" : "REST";
        dc.drawText(CX, 140, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawPending(dc as Graphics.Dc) as Void {
        dc.drawText(CX, 62, Graphics.FONT_MEDIUM, _remaining, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX, 94, Graphics.FONT_XTINY, "until start", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX, 140, Graphics.FONT_SMALL, "PENDING", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draws total watch progress (start date → end date) in the secondary round display.
    // Called last to overwrite any main-arc pixels that leak into that circle region.
    private function _drawTotalCircle(dc as Graphics.Dc) as Void {
        // Clear the physical secondary display (r=31)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(CCX, CCY, 31);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawCircle(CCX, CCY, CCR);

        // Progress arc: clockwise from 90° (top), full sweep = 360°
        if (_totalPct > 0) {
            var endDeg = ((90 - _totalPct * 360 / 100) + 360) % 360;
            var ri;
            for (ri = CCR - 4; ri <= CCR; ri++) {
                dc.drawArc(CCX, CCY, ri, Graphics.ARC_CLOCKWISE, 90, endDeg);
            }
        }

        dc.drawText(CCX, CCY - 7, Graphics.FONT_XTINY,
            _totalPct.toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
