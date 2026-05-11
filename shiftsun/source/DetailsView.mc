using Toybox.WatchUi;
using Toybox.Graphics;

class DetailsView extends WatchUi.View {

    private const CX = 88;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        var dd = _pad2(WatchSchedule.startDay);
        var mm = _pad2(WatchSchedule.startMonth);
        var hh = _pad2(WatchSchedule.startHour);

        dc.drawText(CX, 20, Graphics.FONT_SMALL,
            dd + "." + mm + "." + WatchSchedule.startYear.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(CX, 48, Graphics.FONT_SMALL,
            hh + ":00 start",
            Graphics.TEXT_JUSTIFY_CENTER);

        var onH = WatchSchedule.onDutyMin / 60;
        var rH  = WatchSchedule.restMin   / 60;
        dc.drawText(CX, 76, Graphics.FONT_SMALL,
            onH.toString() + "h ON / " + rH.toString() + "h REST",
            Graphics.TEXT_JUSTIFY_CENTER);

        var cycleH = (WatchSchedule.onDutyMin + WatchSchedule.restMin) / 60;
        dc.drawText(CX, 104, Graphics.FONT_SMALL,
            "cycle: " + cycleH.toString() + "h",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(CX, 155, Graphics.FONT_XTINY,
            "BACK to return",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _pad2(n) {
        if (n < 10) { return "0" + n.toString(); }
        return n.toString();
    }
}
