using Toybox.WatchUi;
using Toybox.Graphics;

class DetailsView extends WatchUi.View {

    private const CX_LEFT = 65;
    private const CCX     = 144;
    private const CCY     = 31;
    private const CCR     = 27;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        var dd = _pad2(WatchSchedule.startDay);
        var mm = _pad2(WatchSchedule.startMonth);
        var hh = _pad2(WatchSchedule.startHour);

        dc.drawText(CX_LEFT, 13, Graphics.FONT_XTINY, "START",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX_LEFT, 27, Graphics.FONT_SMALL,
            dd + "." + mm + "." + WatchSchedule.startYear.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CX_LEFT, 47, Graphics.FONT_XTINY, hh + ":00",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawLine(14, 67, 162, 67);

        var onH    = WatchSchedule.onDutyMin / 60;
        var rH     = WatchSchedule.restMin   / 60;
        var cycleH = onH + rH;

        dc.drawText(14,  75, Graphics.FONT_XTINY, "ON DUTY", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(162, 75, Graphics.FONT_SMALL,  onH.toString() + "h", Graphics.TEXT_JUSTIFY_RIGHT);

        dc.drawText(14,  99, Graphics.FONT_XTINY, "REST", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(162, 99, Graphics.FONT_SMALL,  rH.toString() + "h", Graphics.TEXT_JUSTIFY_RIGHT);

        dc.drawText(14,  123, Graphics.FONT_XTINY, "CYCLE", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(162, 123, Graphics.FONT_SMALL,  cycleH.toString() + "h", Graphics.TEXT_JUSTIFY_RIGHT);

        _drawShiftCircle(dc);
    }

    private function _drawShiftCircle(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillCircle(CCX, CCY, 31);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawCircle(CCX, CCY, CCR);

        var shiftNum = WatchSchedule.shiftNumber();
        dc.drawText(CCX, CCY - 20, Graphics.FONT_XTINY, "#",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(CCX, CCY - 6,  Graphics.FONT_SMALL, shiftNum.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _pad2(n) {
        if (n < 10) { return "0" + n.toString(); }
        return n.toString();
    }
}

class DetailsDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() {
        WatchUi.switchToView(new AnimView(), new AnimDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() {
        WatchUi.switchToView(new MainView(), new WatchTrackerDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }
}
