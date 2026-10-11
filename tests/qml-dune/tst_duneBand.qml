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

    SignalSpy {
        id: painted
        target: band.scene
        signalName: "painted"
    }

    TestCase {
        name: "DuneBand"
        when: windowShown

        // File of the scene on screen, read from the Loader the band holds
        function sceneFile() {
            return band.scene ? band.scene.parent.source : "";
        }

        function init() {
            band.shown = false;
            tryVerify(() => !band.sceneLoaded, 1000);
            band.reduceMotion = false;
            band.style = "grains";
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

        function test_unknown_style_draws_grains() {
            band.style = "nonsense";
            compare(band.drawn, "grains");
            band.style = "";
            compare(band.drawn, "grains");
        }

        function test_each_style_data() {
            return [
                {tag: "grains", file: "GrainsScene.qml", ms: 2900},
                {tag: "wind", file: "WindScene.qml", ms: 2600}
            ];
        }

        // Its own scene file, a size, a run that ends by itself, then no repaint
        function test_each_style(row) {
            band.style = row.tag;
            compare(band.drawn, row.tag);
            band.shown = true;
            verify(band.scene !== null, "scene loaded");
            verify(String(sceneFile()).endsWith("/" + row.file), "scene file: " + sceneFile());
            compare(band.scene.width, 900);
            compare(band.scene.height, 200);
            verify(band.scene.reach > 0 && band.scene.reach < 1, "reach leaves room above the crest");
            compare(band.duneState.style, row.tag);
            compare(band.duneState.steps, Math.round(row.ms * 30 / 1000));
            verify(band.animating, "timer runs");
            tryVerify(() => band.legendVisible, 2000, "legend shows during the run");
            tryVerify(() => painted.count > 0, 1000, "the scene paints while it runs");
            tryVerify(() => !band.animating, row.ms + 1500, "timer stops on the last step");
            verify(band.duneState.done, "posed at the end");
            verify(band.legendVisible, "legend stays");
            // Nothing asks for a new picture once the run has ended
            wait(200);
            painted.clear();
            const state = band.duneState;
            wait(400);
            compare(painted.count, 0, "no repaint after the stop");
            verify(band.duneState === state, "no new state after the stop");
            band.shown = false;
            tryVerify(() => !band.sceneLoaded, 1000, "unloaded once dismissed");
            verify(!band.animating);
        }

        function test_each_style_reduce_motion_data() {
            return test_each_style_data();
        }

        function test_each_style_reduce_motion(row) {
            band.style = row.tag;
            band.reduceMotion = true;
            band.shown = true;
            verify(band.scene !== null, "scene loaded");
            verify(!band.animating, "no timer under Reduce motion");
            verify(band.duneState.done, "posed at once");
            compare(band.duneState.steps, 0);
            compare(band.duneState.style, row.tag);
            verify(band.legendVisible, "legend at once");
        }

        function test_each_style_narrow_data() {
            return test_each_style_data();
        }

        // 360 px and a long name: the posed sand is behind the whole legend
        function test_each_style_narrow(row) {
            root.width = 360;
            band.name = "A very long timer name that cannot possibly fit in a narrow screen strip";
            band.style = row.tag;
            band.reduceMotion = true;
            band.shown = true;
            verify(band.legendVisible);
            verify(band.legend.width <= 360 - 32, "legend fits: " + band.legend.width);
            const h = band.duneState.heights, low = Math.min(...h) * band.scene.reach * 200;
            verify(low >= 200 - band.legend.y - 13, "lowest sand " + low + " px reaches the caption text");
        }

        // A style picked while the alert shows starts its own run and still ends
        function test_style_change_while_shown() {
            band.shown = true;
            wait(150);
            band.style = "wind";
            tryVerify(() => band.scene !== null && String(sceneFile()).endsWith("/WindScene.qml"), 1000);
            compare(band.duneState.style, "wind");
            verify(band.duneState.step < 5, "run restarted: step " + band.duneState.step);
            tryVerify(() => !band.animating, 4000, "timer stops");
            verify(band.duneState.done);
        }

        function test_dismiss_mid_run_each_style_data() {
            return test_each_style_data();
        }

        function test_dismiss_mid_run_each_style(row) {
            band.style = row.tag;
            band.shown = true;
            wait(300);
            band.shown = false;
            verify(!band.animating, "timer stopped mid run");
            tryVerify(() => !band.sceneLoaded, 1000, "Loader inactive mid run");
            compare(band.scene, null);
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
