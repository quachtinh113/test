from __future__ import annotations

from datetime import datetime, time
from zoneinfo import ZoneInfo

from .config import SessionConfig


class SessionClock:
    def __init__(self, session_cfg: SessionConfig, timezone: str) -> None:
        self.cfg = session_cfg
        self.tz = ZoneInfo(timezone)

    def is_half_hour_block(self, ts: datetime) -> bool:
        local = ts.astimezone(self.tz)
        return local.minute in (0, 30)

    def _in_window(self, value: time, start: time, end: time) -> bool:
        return start <= value <= end

    def session_name(self, ts: datetime) -> str | None:
        local_t = ts.astimezone(self.tz).time().replace(second=0, microsecond=0)
        if self._in_window(local_t, self.cfg.asia_start, self.cfg.asia_end):
            return "ASIA"
        if self._in_window(local_t, self.cfg.eu_start, self.cfg.eu_end):
            return "EU"
        if self._in_window(local_t, self.cfg.us_start, self.cfg.us_end):
            return "US"
        return None

    def can_evaluate_entry(self, ts: datetime) -> bool:
        return self.is_half_hour_block(ts) and self.session_name(ts) is not None

    def hour_block(self, ts: datetime) -> str:
        local = ts.astimezone(self.tz)
        minute = 0 if local.minute < 30 else 30
        return f"{local.hour:02d}:{minute:02d}"
