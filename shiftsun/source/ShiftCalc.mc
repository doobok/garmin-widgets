module WatchSchedule {

    using Toybox.Application;
    using Toybox.Time;
    using Toybox.Time.Gregorian;

    const DEF_START_YEAR  = 2026;
    const DEF_START_MONTH = 4;
    const DEF_START_DAY   = 15;
    const DEF_START_HOUR  = 14;
    const DEF_ON_DUTY_H   = 6;
    const DEF_REST_H      = 12;
    const DEF_END_YEAR    = 2026;
    const DEF_END_MONTH   = 7;
    const DEF_END_DAY     = 15;

    var startYear  = DEF_START_YEAR;
    var startMonth = DEF_START_MONTH;
    var startDay   = DEF_START_DAY;
    var startHour  = DEF_START_HOUR;
    var onDutyMin  = DEF_ON_DUTY_H * 60;
    var restMin    = DEF_REST_H * 60;
    var endYear    = DEF_END_YEAR;
    var endMonth   = DEF_END_MONTH;
    var endDay     = DEF_END_DAY;

    function loadConfig() {
        var app = Application.getApp();
        var v;

        v = app.getProperty("startYear");
        startYear = (v != null) ? v : DEF_START_YEAR;

        v = app.getProperty("startMonth");
        startMonth = (v != null) ? v : DEF_START_MONTH;

        v = app.getProperty("startDay");
        startDay = (v != null) ? v : DEF_START_DAY;

        v = app.getProperty("startHour");
        startHour = (v != null) ? v : DEF_START_HOUR;

        v = app.getProperty("onDutyHours");
        var odh = (v != null) ? v : DEF_ON_DUTY_H;
        onDutyMin = (odh > 0 ? odh : DEF_ON_DUTY_H) * 60;

        v = app.getProperty("restHours");
        var rh = (v != null) ? v : DEF_REST_H;
        restMin = (rh > 0 ? rh : DEF_REST_H) * 60;

        v = app.getProperty("endYear");
        endYear = (v != null) ? v : DEF_END_YEAR;

        v = app.getProperty("endMonth");
        endMonth = (v != null) ? v : DEF_END_MONTH;

        v = app.getProperty("endDay");
        endDay = (v != null) ? v : DEF_END_DAY;
    }

    // Gregorian.moment() treats input as UTC on the simulator (and some devices).
    // Subtract the local UTC offset so startHour is interpreted as local time.
    function _startRef() {
        var m = Gregorian.moment({
            :year => startYear, :month => startMonth, :day => startDay,
            :hour => startHour, :minute => 0, :second => 0
        });
        var now = Time.now();
        var tzSec = (Gregorian.info(now, Time.FORMAT_SHORT).hour
                   - Gregorian.utcInfo(now, Time.FORMAT_SHORT).hour) * 3600;
        if (tzSec >  43200) { tzSec -= 86400; }
        if (tzSec < -43200) { tzSec += 86400; }
        return new Time.Moment(m.value() - tzSec);
    }

    // Returns minutes elapsed in current cycle, -1 if before schedule start
    function elapsedInCycle() {
        var cycleMin = onDutyMin + restMin;
        if (cycleMin == 0) { return -1; }

        var ref = _startRef();

        var elapsedSec = Time.now().value() - ref.value();
        if (elapsedSec < 0) { return -1; }

        var elapsedMin = (elapsedSec / 60).toNumber();
        var pos = elapsedMin % cycleMin;
        if (pos < 0) { pos += cycleMin; }
        return pos;
    }

    function isOnDuty() {
        var pos = elapsedInCycle();
        if (pos < 0) { return true; }
        return pos < onDutyMin;
    }

    function blockProgress() {
        var pos = elapsedInCycle();
        if (pos < 0) { return 0; }
        if (pos < onDutyMin) {
            return onDutyMin > 0 ? pos * 100 / onDutyMin : 0;
        }
        return restMin > 0 ? (pos - onDutyMin) * 100 / restMin : 0;
    }

    function blockRemaining() {
        var pos = elapsedInCycle();
        if (pos < 0) { return 0; }
        if (pos < onDutyMin) { return onDutyMin - pos; }
        return onDutyMin + restMin - pos;
    }

    function isPending() {
        return elapsedInCycle() < 0;
    }

    function totalProgress() {
        var startRef = _startRef();
        var endRef = Gregorian.moment({
            :year => endYear, :month => endMonth, :day => endDay,
            :hour => 0, :minute => 0, :second => 0
        });
        var totalSec = endRef.value() - startRef.value();
        if (totalSec <= 0) { return 0; }
        var elapsedSec = Time.now().value() - startRef.value();
        if (elapsedSec <= 0) { return 0; }
        if (elapsedSec >= totalSec) { return 100; }
        return (elapsedSec * 100 / totalSec).toNumber();
    }

    // Returns 0–1000 (tenths of a percent) for voyage overall progress
    function totalProgressX10() {
        var startRef = _startRef();
        var endRef = Gregorian.moment({
            :year => endYear, :month => endMonth, :day => endDay,
            :hour => 0, :minute => 0, :second => 0
        });
        var totalSec = endRef.value() - startRef.value();
        if (totalSec <= 0) { return 0; }
        var elapsedSec = Time.now().value() - startRef.value();
        if (elapsedSec <= 0) { return 0; }
        if (elapsedSec >= totalSec) { return 1000; }
        // divide to minutes first to avoid 32-bit overflow (elapsedSec*1000 > 2^31)
        var totalMin = totalSec / 60;
        if (totalMin <= 0) { return 0; }
        var elapsedMin = elapsedSec / 60;
        return elapsedMin * 1000 / totalMin;
    }

    function cycleProgress() {
        var cycleMin = onDutyMin + restMin;
        if (cycleMin == 0) { return 0; }
        var pos = elapsedInCycle();
        if (pos < 0) { return 0; }
        return pos * 100 / cycleMin;
    }

    function voyageRemainingSec() {
        var endRef = Gregorian.moment({
            :year => endYear, :month => endMonth, :day => endDay,
            :hour => 0, :minute => 0, :second => 0
        });
        var remaining = endRef.value() - Time.now().value();
        if (remaining < 0) { return 0; }
        return remaining;
    }

    function shiftNumber() {
        var ref = _startRef();
        var elapsedSec = Time.now().value() - ref.value();
        if (elapsedSec < 0) { return 1; }
        var cycleMin = onDutyMin + restMin;
        if (cycleMin == 0) { return 1; }
        var elapsedMin = (elapsedSec / 60).toNumber();
        var cycleNum = elapsedMin / cycleMin;
        var pos = elapsedMin % cycleMin;
        if (pos < 0) { pos += cycleMin; }
        if (pos >= onDutyMin) { return cycleNum + 2; }
        return cycleNum + 1;
    }

    function minutesUntilStart() {
        var ref = _startRef();
        var diff = ref.value() - Time.now().value();
        if (diff <= 0) { return 0; }
        return (diff / 60).toNumber();
    }

    function formatMinutes(minutes) {
        if (minutes <= 0) { return "0m"; }
        var h = minutes / 60;
        var m = minutes % 60;
        if (h > 0 && m > 0) { return h.toString() + "h " + m.toString() + "m"; }
        if (h > 0) { return h.toString() + "h"; }
        return m.toString() + "m";
    }
}
