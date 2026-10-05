test "planner day starts at 4 AM" {
    assert time_to_minutes("04:00") == 0;
    assert time_to_minutes("08:00") == 240;
    assert time_to_minutes("01:00") == 1260;
    assert minutes_to_time(240) == "08:00";
    assert minutes_to_time(1260) == "01:00";
}

test "an end time of 04:00 means the end of the planner day" {
    assert end_time_to_minutes("04:00") == DAY_MINUTES;
    assert end_time_to_minutes("09:30") == 330;
}

test "labels read like a clock" {
    assert minutes_to_label(240) == "8:00 AM";
    assert minutes_to_label(480) == "12:00 PM";
    assert minutes_to_label(1200) == "12:00 AM";
    assert hour_row_label(0) == "04 am";
    assert hour_row_label(20) == "12 am";
}

test "validation rejects empty and reversed ranges" {
    assert validate_range(240, 300) == "";
    assert validate_range(300, 300) != "";
    assert validate_range(300, 240) != "";
    assert validate_range(-10, 30) != "";
    assert validate_range(1400, 1450) != "";
}

test "a late-night block stays one increasing range" {
    start = time_to_minutes("23:00");
    end = end_time_to_minutes("01:00");
    assert end - start == 120;
    assert validate_range(start, end) == "";
}

test "time blocks list the covered 10-minute cells" {
    assert time_blocks(240, 300) == [24, 25, 26, 27, 28, 29];
    assert time_blocks(245, 250) == [24];
    assert snap_to_slot(247) == 240;
}
