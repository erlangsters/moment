# Moment

[![Erlangsters Repository](https://img.shields.io/badge/erlangsters-moment-%23a90432)](https://github.com/erlangsters/moment)
![Supported Erlang/OTP Versions](https://img.shields.io/badge/erlang%2Fotp-27%7C28%7C29-%23a90432)
![Current Version](https://img.shields.io/badge/version-0.0.1-%23354052)
![License](https://img.shields.io/github/license/erlangsters/moment)
[![Build Status](https://img.shields.io/github/actions/workflow/status/erlangsters/moment/build.yml)](https://github.com/erlangsters/moment/actions/workflows/build.yml)
[![Documentation Link](https://img.shields.io/badge/documentation-available-yellow)](http://erlangsters.github.io/moment/)

A typed civil-time library for Erlang.

It is not a Moment.js port and not a `qdate` clone. OTP’s `calendar` module gives untagged `{Y,M,D}` / `{H,Min,S}` tuples, integer seconds only, and no duration type. Moment fills that gap with tagged Gregorian values and exact arithmetic.

```erlang
{ok, Date} = moment:date(2024, 1, 23),
{ok, Time} = moment:time(12, 45, 0),
{ok, DT} = moment:datetime(Date, Time),
{ok, Shift} = moment:duration({hour, 3}),
Later = moment:add_datetime(DT, Shift),
Instant = moment:to_instant(Later, utc).
```

The five public types are `date()`, `time()`, `datetime()`, `instant()`, and `duration()`. Arithmetic uses split names (`add_date/2`, `add_datetime/2`, `add_instant/2`, `add_duration/2`, and matching `subtract_*` / `diff_*`). There is no overloaded `add/2` and no calendar `shift` by months.

Written by the Erlangsters [community](https://about.erlangsters.org/) and released under the MIT [license](https://opensource.org/license/mit).

## Getting started

Civil constructors return `{ok, Value}` or `{error, Reason}`. Instant constructors always succeed. `{10, 10, 10}` is a date only if you call `date/1`, and a time of day only if you call `time/1`.

```erlang
{ok, Date} = moment:date({2024, 1, 23}),
{2024, 1, 23} = moment:to_otp_date(Date),
{error, invalid_date} = moment:date(2023, 2, 29),
{error, invalid_time} = moment:time(12, 45, 66).
```

The clock is `moment:instant/0` (`erlang:system_time(microsecond)`). `now/0` is an alias of that function, not `erlang:now/0`. Naive datetime is not UTC unless you pass `utc` into `to_instant/2` or `from_instant/2`. Offsets are minute-aligned seconds east of UTC, bounded `±86400`. There is no OS-local clock export and no IANA timezone table.

```erlang
Now = moment:instant(),
Utc = moment:from_instant(Now, utc),
{ok, Parsed} = moment:parse_rfc3339(<<"2018-02-01T16:17:58+01:00">>),
<<"2018-02-01T15:17:58Z">> = moment:format(Parsed).
```

Duration is exact elapsed time. `{hour, 24}` and `PT24H` format as `P1D`. Months and years are rejected. Store hours use `diff_time/2`; adding a duration to a time of day is `badarg`.

## Installing the library

To use `moment` in a `rebar3` project, add it to your `rebar.config`.

```erlang
{deps, [
  {moment, {git, "https://github.com/erlangsters/moment.git", {tag, "0.0.1"}}}
]}.
```
