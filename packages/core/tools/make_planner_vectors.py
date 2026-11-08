#!/usr/bin/env python3
"""Writes test-vectors/planner.json. Every EXPECTED value is written by hand from calendar and time-zone facts
(Asia/Colombo is UTC+05:30 all year; Europe/London is UTC+0 in winter and UTC+1 from 2026-03-29 to 2026-10-25).
The only computation here is adding a fixed duration to a hand-written start. Run: make_planner_vectors.py [--check]"""
import datetime as dt
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "test-vectors", "planner.json")
FMT = "%Y-%m-%dT%H:%M:%SZ"


def E(start, dur=150, o=False):
    end = (dt.datetime.strptime(start, FMT) + dt.timedelta(minutes=dur)).strftime(FMT)
    d = {"s": start, "e": end}
    if o:
        d["o"] = True
    return d


def X(name, rule, start, zone, frm, to, expect, dur=150, skip=(), override=()):
    return {"name": name, "rule": rule, "start": start, "zone": zone, "durationMin": dur, "from": frm, "to": to,
            "skip": list(skip), "override": list(override), "expect": expect}


CO = "Asia/Colombo"
TUE = "FREQ=WEEKLY;BYDAY=TU"
W1 = ("2026-10-19T00:00:00Z", "2026-11-17T00:00:00Z")
V = {
  "limits": {"titleMax": 80, "locationMax": 120, "notesMax": 2000, "reminderOffsetMax": 10080, "reminderCountMax": 5, "meetingUrlMax": 500, "eventMaxHours": 24,
             "categories": ["study", "revision", "homework", "break", "online_class"], "preferredBlockMinutes": [150, 240]},
  "rrule": {
    "valid": [
      {"in": "FREQ=WEEKLY;BYDAY=TU", "canonical": "FREQ=WEEKLY;BYDAY=TU"},
      {"in": "BYDAY=TU;FREQ=WEEKLY", "canonical": "FREQ=WEEKLY;BYDAY=TU"},
      {"in": "FREQ=WEEKLY;INTERVAL=1;BYDAY=TU", "canonical": "FREQ=WEEKLY;BYDAY=TU"},
      {"in": "FREQ=WEEKLY;BYDAY=TH,MO,TU", "canonical": "FREQ=WEEKLY;BYDAY=MO,TU,TH"},
      {"in": "FREQ=MONTHLY;BYMONTHDAY=-1,15,1", "canonical": "FREQ=MONTHLY;BYMONTHDAY=1,15,-1"},
      {"in": "FREQ=DAILY;COUNT=5", "canonical": "FREQ=DAILY;COUNT=5"},
      {"in": "FREQ=DAILY;UNTIL=20261231T235959Z", "canonical": "FREQ=DAILY;UNTIL=20261231T235959Z"},
      {"in": "COUNT=1000;BYMONTHDAY=31;INTERVAL=12;FREQ=MONTHLY", "canonical": "FREQ=MONTHLY;INTERVAL=12;BYMONTHDAY=31;COUNT=1000"},
      {"in": "FREQ=DAILY;INTERVAL=999", "canonical": "FREQ=DAILY;INTERVAL=999"},
    ],
    "invalid": [
      {"in": "", "code": "empty"},
      {"in": "FREQ=YEARLY", "code": "unsupported_freq"},
      {"in": "INTERVAL=2", "code": "missing_freq"},
      {"in": "FREQ=WEEKLY;BYDAY=1TU", "code": "invalid_byday"},
      {"in": "FREQ=WEEKLY;BYDAY=TU,TU", "code": "invalid_byday", "sqlMayAccept": True},
      {"in": "FREQ=WEEKLY;BYDAY=XX", "code": "invalid_byday"},
      {"in": "FREQ=DAILY;BYDAY=MO", "code": "byday_needs_weekly"},
      {"in": "FREQ=WEEKLY;BYMONTHDAY=1", "code": "bymonthday_needs_monthly"},
      {"in": "FREQ=MONTHLY;BYMONTHDAY=32", "code": "invalid_bymonthday"},
      {"in": "FREQ=MONTHLY;BYMONTHDAY=-2", "code": "invalid_bymonthday"},
      {"in": "FREQ=MONTHLY;BYMONTHDAY=0", "code": "invalid_bymonthday"},
      {"in": "FREQ=MONTHLY;BYMONTHDAY=5,5", "code": "invalid_bymonthday", "sqlMayAccept": True},
      {"in": "FREQ=WEEKLY;INTERVAL=0", "code": "invalid_interval"},
      {"in": "FREQ=WEEKLY;INTERVAL=1000", "code": "invalid_interval"},
      {"in": "FREQ=DAILY;COUNT=0", "code": "invalid_count"},
      {"in": "FREQ=DAILY;COUNT=1001", "code": "invalid_count"},
      {"in": "FREQ=DAILY;COUNT=1.5", "code": "invalid_count"},
      {"in": "FREQ=DAILY;COUNT=3;UNTIL=20261231T000000Z", "code": "count_and_until"},
      {"in": "FREQ=DAILY;UNTIL=2026-12-31", "code": "invalid_until"},
      {"in": "FREQ=DAILY;UNTIL=20261331T000000Z", "code": "invalid_until"},
      {"in": "freq=daily", "code": "unsupported_key"},
      {"in": "FREQ=DAILY;WKST=MO", "code": "unsupported_key"},
      {"in": "FREQ=DAILY;FREQ=DAILY", "code": "duplicate_key"},
      {"in": "FREQ=DAILY;", "code": "invalid_syntax"},
      {"in": "FREQ", "code": "invalid_syntax"},
      {"in": "FREQ=DAILY ", "code": "invalid_syntax"},
      {"in": "FREQ=DAILY;COUNT=" + "9" * 190, "code": "too_long"},
    ],
  },
  "expand": [
    X("the Tuesday 7:30 PM class recurs every week", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-11-03T14:00:00Z"), E("2026-11-10T14:00:00Z")]),
    X("a one-hour duration", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z", 60), E("2026-10-27T14:00:00Z", 60), E("2026-11-03T14:00:00Z", 60), E("2026-11-10T14:00:00Z", 60)], dur=60),
    X("every second week", "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU", "2026-10-20T19:30", CO, "2026-10-19T00:00:00Z", "2026-12-02T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-11-03T14:00:00Z"), E("2026-11-17T14:00:00Z"), E("2026-12-01T14:00:00Z")]),
    X("Tuesday and Thursday", "FREQ=WEEKLY;BYDAY=TU,TH", "2026-10-20T19:30", CO, "2026-10-19T00:00:00Z", "2026-10-30T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-10-22T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-10-29T14:00:00Z")]),
    X("the first week is partial: Monday before the start is not generated", "FREQ=WEEKLY;BYDAY=MO,WE", "2026-10-21T07:00", CO, "2026-10-19T00:00:00Z", "2026-10-30T00:00:00Z",
      [E("2026-10-21T01:30:00Z"), E("2026-10-26T01:30:00Z"), E("2026-10-28T01:30:00Z")]),
    X("COUNT=3 stops after three", "FREQ=WEEKLY;BYDAY=TU;COUNT=3", "2026-10-20T19:30", CO, "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-11-03T14:00:00Z")]),
    X("UNTIL excludes an occurrence after the instant", "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261103T000000Z", "2026-10-20T19:30", CO, "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z")]),
    X("UNTIL includes an occurrence exactly at the instant", "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261103T140000Z", "2026-10-20T19:30", CO, "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-11-03T14:00:00Z")]),
    X("every third day across the new year", "FREQ=DAILY;INTERVAL=3", "2026-12-30T08:00", CO, "2026-12-29T00:00:00Z", "2027-01-09T00:00:00Z",
      [E("2026-12-30T02:30:00Z"), E("2027-01-02T02:30:00Z"), E("2027-01-05T02:30:00Z"), E("2027-01-08T02:30:00Z")]),
    X("last day of the month (28 days in February 2026)", "FREQ=MONTHLY;BYMONTHDAY=-1", "2026-01-31T20:00", CO, "2026-01-01T00:00:00Z", "2026-05-01T00:00:00Z",
      [E("2026-01-31T14:30:00Z"), E("2026-02-28T14:30:00Z"), E("2026-03-31T14:30:00Z"), E("2026-04-30T14:30:00Z")]),
    X("last day of the month in a leap year", "FREQ=MONTHLY;BYMONTHDAY=-1", "2028-01-31T20:00", CO, "2028-01-01T00:00:00Z", "2028-04-01T00:00:00Z",
      [E("2028-01-31T14:30:00Z"), E("2028-02-29T14:30:00Z"), E("2028-03-31T14:30:00Z")]),
    X("the 31st skips months that have no 31st", "FREQ=MONTHLY;BYMONTHDAY=31", "2026-01-31T20:00", CO, "2026-01-01T00:00:00Z", "2026-08-01T00:00:00Z",
      [E("2026-01-31T14:30:00Z"), E("2026-03-31T14:30:00Z"), E("2026-05-31T14:30:00Z"), E("2026-07-31T14:30:00Z")]),
    X("the 30th skips February", "FREQ=MONTHLY;BYMONTHDAY=30", "2026-01-30T20:00", CO, "2026-01-01T00:00:00Z", "2026-06-01T00:00:00Z",
      [E("2026-01-30T14:30:00Z"), E("2026-03-30T14:30:00Z"), E("2026-04-30T14:30:00Z"), E("2026-05-30T14:30:00Z")]),
    X("monthly without BYMONTHDAY uses the day of the start", "FREQ=MONTHLY", "2026-01-31T20:00", CO, "2026-01-01T00:00:00Z", "2026-08-01T00:00:00Z",
      [E("2026-01-31T14:30:00Z"), E("2026-03-31T14:30:00Z"), E("2026-05-31T14:30:00Z"), E("2026-07-31T14:30:00Z")]),
    X("two days a month", "FREQ=MONTHLY;BYMONTHDAY=1,15", "2026-03-01T20:00", CO, "2026-03-01T00:00:00Z", "2026-04-20T00:00:00Z",
      [E("2026-03-01T14:30:00Z"), E("2026-03-15T14:30:00Z"), E("2026-04-01T14:30:00Z"), E("2026-04-15T14:30:00Z")]),
    X("every second month", "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=10", "2026-01-10T20:00", CO, "2026-01-01T00:00:00Z", "2026-06-01T00:00:00Z",
      [E("2026-01-10T14:30:00Z"), E("2026-03-10T14:30:00Z"), E("2026-05-10T14:30:00Z")]),
    X("local Monday 03:00 is Sunday 21:30 UTC", "FREQ=WEEKLY;BYDAY=MO", "2026-10-19T03:00", CO, "2026-10-18T00:00:00Z", "2026-11-03T00:00:00Z",
      [E("2026-10-18T21:30:00Z"), E("2026-10-25T21:30:00Z"), E("2026-11-01T21:30:00Z")]),
    X("a skipped occurrence is removed", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z"), E("2026-11-03T14:00:00Z"), E("2026-11-10T14:00:00Z")], skip=["2026-10-27T14:00:00Z"]),
    X("an overridden occurrence moves", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-11-04T18:00:00Z", 150, True), E("2026-11-10T14:00:00Z")],
      override=[{"original": "2026-11-03T14:00:00Z", "start": "2026-11-04T18:00:00Z", "end": "2026-11-04T20:30:00Z"}]),
    X("an occurrence overridden to a time outside the window disappears", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z"), E("2026-11-03T14:00:00Z"), E("2026-11-10T14:00:00Z")],
      override=[{"original": "2026-10-27T14:00:00Z", "start": "2026-12-01T10:00:00Z", "end": "2026-12-01T12:30:00Z"}]),
    X("an occurrence from outside the window overridden INTO it appears", TUE, "2026-10-20T19:30", CO, *W1,
      [E("2026-10-20T14:00:00Z"), E("2026-10-27T14:00:00Z"), E("2026-11-03T14:00:00Z"), E("2026-11-10T14:00:00Z"), E("2026-11-12T10:00:00Z", 150, True)],
      override=[{"original": "2026-11-17T14:00:00Z", "start": "2026-11-12T10:00:00Z", "end": "2026-11-12T12:30:00Z"}]),
    X("COUNT counts skipped occurrences too", "FREQ=WEEKLY;BYDAY=TU;COUNT=3", "2026-10-20T19:30", CO, "2026-01-01T00:00:00Z", "2030-01-01T00:00:00Z",
      [E("2026-10-20T14:00:00Z"), E("2026-11-03T14:00:00Z")], skip=["2026-10-27T14:00:00Z"]),
    X("London: a time that does not exist (spring forward) moves forward", "FREQ=WEEKLY;BYDAY=SU", "2026-03-22T01:30", "Europe/London", "2026-03-22T00:00:00Z", "2026-04-06T00:00:00Z",
      [E("2026-03-22T01:30:00Z", 60), E("2026-03-29T01:30:00Z", 60), E("2026-04-05T00:30:00Z", 60)], dur=60),
    X("London: a time that happens twice (fall back) means the first one", "FREQ=WEEKLY;BYDAY=SU", "2026-10-11T01:30", "Europe/London", "2026-10-11T00:00:00Z", "2026-11-02T00:00:00Z",
      [E("2026-10-11T00:30:00Z", 60), E("2026-10-18T00:30:00Z", 60), E("2026-10-25T00:30:00Z", 60), E("2026-11-01T01:30:00Z", 60)], dur=60),
    X("London: the local class time stays 19:30 while UTC shifts", "FREQ=WEEKLY;BYDAY=TU", "2026-03-24T19:30", "Europe/London", "2026-03-24T00:00:00Z", "2026-04-08T00:00:00Z",
      [E("2026-03-24T19:30:00Z", 60), E("2026-03-31T18:30:00Z", 60), E("2026-04-07T18:30:00Z", 60)], dur=60),
  ],
  "split": [
    {"name": "COUNT is divided between the two series", "rule": "FREQ=WEEKLY;BYDAY=TU;COUNT=10", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T14:00:00Z",
     "first": "FREQ=WEEKLY;BYDAY=TU;COUNT=3", "second": "FREQ=WEEKLY;BYDAY=TU;COUNT=7", "secondStartUtc": "2026-11-10T14:00:00Z"},
    {"name": "the last occurrence of a COUNT series", "rule": "FREQ=WEEKLY;BYDAY=TU;COUNT=4", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T14:00:00Z",
     "first": "FREQ=WEEKLY;BYDAY=TU;COUNT=3", "second": "FREQ=WEEKLY;BYDAY=TU;COUNT=1", "secondStartUtc": "2026-11-10T14:00:00Z"},
    {"name": "an UNTIL series ends one second before the split", "rule": "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T000000Z", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T14:00:00Z",
     "first": "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261110T135959Z", "second": "FREQ=WEEKLY;BYDAY=TU;UNTIL=20270101T000000Z", "secondStartUtc": "2026-11-10T14:00:00Z"},
    {"name": "an open-ended series", "rule": "FREQ=WEEKLY;BYDAY=TU", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T14:00:00Z",
     "first": "FREQ=WEEKLY;BYDAY=TU;UNTIL=20261110T135959Z", "second": "FREQ=WEEKLY;BYDAY=TU", "secondStartUtc": "2026-11-10T14:00:00Z"},
    {"name": "splitting at the first occurrence is refused (edit the whole series instead)", "rule": "FREQ=WEEKLY;BYDAY=TU", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-10-20T14:00:00Z", "error": "split_at_first"},
    {"name": "a time that is not an occurrence", "rule": "FREQ=WEEKLY;BYDAY=TU", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T15:00:00Z", "error": "not_an_occurrence"},
    {"name": "an occurrence beyond COUNT does not exist", "rule": "FREQ=WEEKLY;BYDAY=TU;COUNT=3", "start": "2026-10-20T19:30", "zone": CO, "at": "2026-11-10T14:00:00Z", "error": "not_an_occurrence"},
  ],
  "conflicts": [
    {"name": "overlap, then two that only touch", "in": [[600, 720], [700, 800], [800, 900], [900, 1000]], "expect": [[0, 1]]},
    {"name": "one inside another", "in": [[0, 100], [10, 20]], "expect": [[0, 1]]},
    {"name": "identical", "in": [[5, 10], [5, 10]], "expect": [[0, 1]]},
    {"name": "three at once", "in": [[0, 60], [30, 90], [45, 120]], "expect": [[0, 1], [0, 2], [1, 2]]},
    {"name": "none", "in": [], "expect": []},
    {"name": "an interval that ends before it starts is invalid", "in": [[10, 10]], "error": "invalid_interval"},
  ],
  "freeSlots": [
    {"name": "evening class leaves the whole day", "window": [360, 1320], "busy": [[1170, 1320]], "min": 150, "max": 240, "buffer": 0, "expect": [[360, 600]]},
    {"name": "a buffer around the class changes nothing for the first block", "window": [360, 1320], "busy": [[1170, 1320]], "min": 150, "max": 240, "buffer": 15, "expect": [[360, 600]]},
    {"name": "gaps that are too short are ignored, long gaps are trimmed to the maximum", "window": [360, 1320], "busy": [[480, 540], [720, 780]], "min": 150, "max": 240, "buffer": 0, "expect": [[540, 720], [780, 1020]]},
    {"name": "buffers can swallow a gap", "window": [360, 1320], "busy": [[480, 540], [720, 780]], "min": 150, "max": 240, "buffer": 30, "expect": [[810, 1050]]},
    {"name": "overlapping busy periods merge", "window": [360, 1320], "busy": [[480, 600], [570, 700]], "min": 150, "max": 240, "buffer": 0, "expect": [[700, 940]]},
    {"name": "busy time outside the window is ignored", "window": [360, 1320], "busy": [[0, 300]], "min": 150, "max": 240, "buffer": 0, "expect": [[360, 600]]},
    {"name": "a fully busy window", "window": [360, 1320], "busy": [[300, 1400]], "min": 150, "max": 240, "buffer": 0, "expect": []},
    {"name": "a minimum above the maximum is invalid", "window": [360, 1320], "busy": [], "min": 300, "max": 240, "buffer": 0, "error": "invalid_range"},
  ],
  "durationHint": [
    {"minutes": 149, "expect": "short"}, {"minutes": 150, "expect": "within"}, {"minutes": 240, "expect": "within"}, {"minutes": 241, "expect": "long"}, {"minutes": 45, "expect": "short"},
  ],
  "meetingUrl": [
    {"name": "Zoom", "in": "https://zoom.us/j/123456789?pwd=abc", "code": "ok", "provider": "zoom", "normalized": "https://zoom.us/j/123456789?pwd=abc"},
    {"name": "Zoom subdomain", "in": "https://us02web.zoom.us/j/123", "code": "ok", "provider": "zoom", "normalized": "https://us02web.zoom.us/j/123"},
    {"name": "Google Meet", "in": "https://meet.google.com/abc-defg-hij", "code": "ok", "provider": "meet", "normalized": "https://meet.google.com/abc-defg-hij"},
    {"name": "Teams", "in": "https://teams.microsoft.com/l/meetup-join/xyz", "code": "ok", "provider": "teams", "normalized": "https://teams.microsoft.com/l/meetup-join/xyz"},
    {"name": "Teams (live)", "in": "https://teams.live.com/meet/123", "code": "ok", "provider": "teams", "normalized": "https://teams.live.com/meet/123"},
    {"name": "an unknown host is allowed but flagged by its provider", "in": "https://example.org/class", "code": "ok", "provider": "other", "normalized": "https://example.org/class"},
    {"name": "uppercase scheme and host are normalised", "in": "HTTPS://ZOOM.US/j/1", "code": "ok", "provider": "zoom", "normalized": "https://zoom.us/j/1"},
    {"name": "surrounding spaces are trimmed", "in": "  https://zoom.us/j/1 ", "code": "ok", "provider": "zoom", "normalized": "https://zoom.us/j/1"},
    {"name": "a host with no path", "in": "https://zoom.us", "code": "ok", "provider": "zoom", "normalized": "https://zoom.us"},
    {"name": "a port", "in": "https://zoom.us:8443/j/1", "code": "ok", "provider": "zoom", "normalized": "https://zoom.us:8443/j/1"},
    {"name": "a look-alike suffix is not Zoom", "in": "https://zoom.us.evil.com/j/1", "code": "ok", "provider": "other", "normalized": "https://zoom.us.evil.com/j/1"},
    {"name": "a look-alike prefix is not Zoom", "in": "https://evilzoom.us/j/1", "code": "ok", "provider": "other", "normalized": "https://evilzoom.us/j/1"},
    {"name": "plain http", "in": "http://zoom.us/j/1", "code": "not_https"},
    {"name": "ftp", "in": "ftp://zoom.us/x", "code": "not_https"},
    {"name": "javascript", "in": "javascript:alert(1)", "code": "not_https"},
    {"name": "no scheme at all", "in": "zoom.us/j/1", "code": "not_https"},
    {"name": "credentials in the link", "in": "https://user:pass@zoom.us/j/1", "code": "credentials"},
    {"name": "an IPv4 address", "in": "https://192.168.1.5/x", "code": "ip_host"},
    {"name": "an IPv6 address", "in": "https://[::1]/x", "code": "ip_host"},
    {"name": "a Cyrillic look-alike host", "in": "https://z\u043e\u043em.us/j/1", "code": "invalid_host"},
    {"name": "a host with no dot", "in": "https://localhost/x", "code": "invalid_host"},
    {"name": "a query straight after the host", "in": "https://zoom.us?x=1", "code": "invalid_url"},
    {"name": "a space inside", "in": "https://zoom.us/a b", "code": "invalid_url"},
    {"name": "a port out of range", "in": "https://zoom.us:99999/j/1", "code": "invalid_url", "sqlMayAccept": True},
    {"name": "empty", "in": "", "code": "blank"},
    {"name": "only spaces", "in": "   ", "code": "blank"},
    {"name": "501 characters", "in": "https://zoom.us/" + "a" * 485, "code": "too_long"},
    {"name": "500 characters", "in": "https://zoom.us/" + "a" * 484, "code": "ok", "provider": "zoom", "normalized": "https://zoom.us/" + "a" * 484},
  ],
  "reminders": [
    {"name": "two offsets, sorted by fire time", "starts": ["2026-10-20T14:00:00Z"], "offsets": [10, 60], "now": "2026-10-20T00:00:00Z", "zone": CO,
     "expect": [{"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:00:00Z", "shifted": False}, {"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:50:00Z", "shifted": False}]},
    {"name": "reminders already in the past are dropped", "starts": ["2026-10-20T14:00:00Z"], "offsets": [10, 60], "now": "2026-10-20T13:30:00Z", "zone": CO,
     "expect": [{"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:50:00Z", "shifted": False}]},
    {"name": "a reminder exactly at 'now' is dropped", "starts": ["2026-10-20T14:00:00Z"], "offsets": [10], "now": "2026-10-20T13:50:00Z", "zone": CO, "expect": []},
    {"name": "duplicate offsets give one reminder", "starts": ["2026-10-20T14:00:00Z"], "offsets": [10, 10], "now": "2026-10-20T00:00:00Z", "zone": CO,
     "expect": [{"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:50:00Z", "shifted": False}]},
    {"name": "quiet hours 22:00-06:00: a reminder at 05:30 local moves to 06:00 when that is still before the event", "starts": ["2026-10-21T01:30:00Z"], "offsets": [90], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [1320, 360],
     "expect": [{"event": "2026-10-21T01:30:00Z", "fire": "2026-10-21T00:30:00Z", "shifted": True}]},
    {"name": "a reminder exactly when quiet hours end is not delayed", "starts": ["2026-10-21T01:30:00Z"], "offsets": [60], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [1320, 360],
     "expect": [{"event": "2026-10-21T01:30:00Z", "fire": "2026-10-21T00:30:00Z", "shifted": False}]},
    {"name": "a reminder that would move to the event start or later is dropped", "starts": ["2026-10-21T00:30:00Z"], "offsets": [30], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [1320, 360], "expect": []},
    {"name": "quiet hours that do not wrap midnight", "starts": ["2026-10-20T10:00:00Z"], "offsets": [60], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [780, 900],
     "expect": [{"event": "2026-10-20T10:00:00Z", "fire": "2026-10-20T09:30:00Z", "shifted": True}]},
    {"name": "an evening reminder inside quiet hours moves to the next morning only if the event is later", "starts": ["2026-10-20T17:00:00Z"], "offsets": [30], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [1320, 360], "expect": []},
    {"name": "start equal to end means no quiet hours", "starts": ["2026-10-20T14:00:00Z"], "offsets": [10], "now": "2026-10-20T00:00:00Z", "zone": CO, "quiet": [0, 0],
     "expect": [{"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:50:00Z", "shifted": False}]},
    {"name": "several events", "starts": ["2026-10-20T14:00:00Z", "2026-10-20T08:00:00Z"], "offsets": [15], "now": "2026-10-20T00:00:00Z", "zone": CO,
     "expect": [{"event": "2026-10-20T08:00:00Z", "fire": "2026-10-20T07:45:00Z", "shifted": False}, {"event": "2026-10-20T14:00:00Z", "fire": "2026-10-20T13:45:00Z", "shifted": False}]},
  ],
}


def main(argv):
    text = json.dumps(V, indent=1, ensure_ascii=False, sort_keys=True) + "\n"
    if "--check" in argv:
        ok = os.path.exists(OUT) and open(OUT, encoding="utf-8").read() == text
        print("OK    planner vectors are up to date" if ok else "FAIL  test-vectors/planner.json is out of date: run make_planner_vectors.py")
        return 0 if ok else 1
    open(OUT, "w", encoding="utf-8").write(text)
    n = len(V["rrule"]["valid"]) + len(V["rrule"]["invalid"]) + sum(len(V[k]) for k in V if k not in ("rrule", "limits"))
    print("wrote", os.path.relpath(OUT, ROOT), "-", n, "cases")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
