import QtQuick
import QtTest
import "../../components/alert"

// The Rising dune band, offscreen: nothing exists at rest, the 30 Hz Timer
// stops by itself and the Loader goes inactive when the alert is dismissed.
// Run: tests/qml-dune/run.sh
Item {
    id: root
    width: 900
    height: 200

    DuneBand {
        id: band
        width: parent.width
        height: parent.height
        name: "Pasta"
    }

    TestCase {
        name: "DuneBand"
        when: windowShown

        function init() {
            band.shown = false;
            tryVerify(() => !band.sceneLoaded, 1000);
            band.reduceMotion = false;
            band.name = "Pasta";
            root.width = 900;
        }

        function test_dash_in_name_is_plain() {
            band.name = "A \u2014 B";
            compare(band.shownName, "A - B");
        }

        function test_rest_creates_nothing() {
            verify(!band.sceneLoaded, "no scene at rest");
            verify(!band.animating, "no timer at rest");
            verify(!band.legendVisible, "no legend at rest");
        }

        function test_run_stops_by_itself() {
            band.shown = true;
            verify(band.sceneLoaded, "scene loaded when shown");
            verify(band.animating, "timer runs while the dune rises");
            tryVerify(() => band.legendVisible, 800, "legend within 0.8 s");
            tryVerify(() => !band.animating, 4000, "timer stops on the last step");
            verify(band.duneState.done, "last state is the posed dune");
            verify(band.sceneLoaded, "dune stays until dismissed");
        }

        function test_dismiss_unloads() {
            band.shown = true;
            tryVerify(() => !band.animating, 4000);
            band.shown = false;
            tryVerify(() => !band.sceneLoaded, 1000, "Loader inactive once the fade out has ended");
            verify(!band.animating, "no timer after dismissal");
        }

        function test_dismiss_mid_run() {
            band.shown = true;
            wait(200);
            band.shown = false;
            verify(!band.animating, "timer stopped mid run");
            tryVerify(() => !band.sceneLoaded, 1000, "Loader inactive mid run");
        }

        function test_reduce_motion_is_posed_with_no_step() {
            band.reduceMotion = true;
            band.shown = true;
            verify(!band.animating, "no timer under Reduce motion");
            verify(band.duneState.done, "posed at once");
            compare(band.duneState.steps, 0);
            verify(band.legendVisible, "legend at once");
        }

        function test_style_fallback_draws_grains() {
            band.style = "wind";
            compare(band.drawn, "grains");
            band.style = "nonsense";
            compare(band.drawn, "grains");
            band.style = "grains";
        }

        function test_short_name_is_not_clipped_wide() {
            root.width = 1440;
            band.name = "Pasta";
            band.reduceMotion = true;
            band.shown = true;
            tryVerify(() => band.legendVisible);
            compare(band.nameDrawn, band.nameFull, "Pasta is drawn whole");
        }

        function test_empty_name_falls_back() {
            band.name = "";
            compare(band.shownName, "Timer");
        }

        function test_long_name_is_elided_at_360() {
            root.width = 360;
            band.name = "A very long timer name that cannot possibly fit in a narrow screen strip";
            band.reduceMotion = true;
            band.shown = true;
            verify(band.legend.width <= 360 - 32, "legend fits: " + band.legend.width);
            verify(band.legend.x >= 0, "legend inside the band");
        }
    }
}
