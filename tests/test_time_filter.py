from datetime import datetime, timezone

from trading_bot.config import SessionConfig
from trading_bot.time_filter import SessionClock


def test_time_filter_half_hour_and_session():
    clock = SessionClock(SessionConfig(), "Asia/Ho_Chi_Minh")
    ts_ok = datetime(2025, 1, 10, 1, 0, tzinfo=timezone.utc)  # 08:00 VN
    ts_bad_minute = datetime(2025, 1, 10, 1, 15, tzinfo=timezone.utc)

    assert clock.can_evaluate_entry(ts_ok)
    assert not clock.can_evaluate_entry(ts_bad_minute)
    assert clock.session_name(ts_ok) == "ASIA"
