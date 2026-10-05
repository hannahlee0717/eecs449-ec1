test "timer clock formatting" {
    assert format_clock(0.0) == "00:00";
    assert format_clock(100.0) == "01:40";
    assert format_clock(3725.0) == "1:02:05";
}

test "study hours use real worked time" {
    # Task A: 60 min fully worked + Task B: stopped after 25 min = 01:25.
    assert format_hours(60.0 * 60 + 25.0 * 60) == "01:25";
    assert format_hours(59.0) == "00:00";
}

test "remaining never goes negative" {
    assert remaining_seconds(700.0, 600.0) == 0.0;
    assert remaining_seconds(100.0, 600.0) == 500.0;
}
