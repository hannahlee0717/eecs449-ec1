glob HOUR: float = 3600.0;

test "elapsed comes from timestamps, not a counter" {
    started = 1000000.0;
    # 90 seconds into the run, nothing banked yet.
    assert elapsed_seconds(0.0, RUNNING, started, HOUR, started + 90000.0) == 90.0;
}

test "pause/resume keeps earlier work" {
    # 600 s banked by an earlier run, resumed 30 s ago.
    started = 5000000.0;
    assert elapsed_seconds(600.0, RUNNING, started, HOUR, started + 30000.0) == 630.0;
    # Paused: the start stamp is ignored, only the bank counts.
    assert elapsed_seconds(630.0, PAUSED, 0.0, HOUR, started + 999999.0) == 630.0;
}

test "a throttled tab catches up exactly on its next tick" {
    started = 0.0 + 1.0;
    # Even if the UI did not render for 20 minutes, one read is exact.
    assert elapsed_seconds(0.0, RUNNING, started, HOUR, started + 1200000.0) == 1200.0;
}

test "elapsed is capped at the planned duration" {
    started = 1.0;
    assert elapsed_seconds(0.0, RUNNING, started, 600.0, started + 900000.0) == 600.0;
    assert is_finished(600.0, 600.0);
    assert not is_finished(599.0, 600.0);
}

test "progress drives partial highlighting" {
    assert progress_fraction(1500.0, 3600.0) > 0.41;
    assert progress_fraction(1500.0, 3600.0) < 0.42;
    assert progress_fraction(9999.0, 3600.0) == 1.0;
    assert progress_fraction(10.0, 0.0) == 0.0;
}
