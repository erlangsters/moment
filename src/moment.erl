%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(moment).
-moduledoc """
Tagged Gregorian civil-time values and exact arithmetic.

`date()`, `time()`, `datetime()`, `instant()`, and `duration()` are
pattern-matchable tuples. Instant is POSIX microseconds; datetime is naive.

```erlang
{ok, Date} = moment:date(2024, 1, 23),
{ok, Time} = moment:time(12, 45, 0),
{ok, DT} = moment:datetime(Date, Time),
{ok, Shift} = moment:duration({hour, 3}),
Later = moment:add_datetime(DT, Shift).
```

It is not a Moment.js port and not a `qdate` clone. There is no IANA timezone
in this library, no overloaded `add/2`, and no Hex package.
""".

-compile({no_auto_import, [now/0, min/2, max/2]}).

-export_type([
    year/0, month/0, day/0,
    hour/0, minute/0, second/0, frac_microsecond/0,
    iso_week_year/0,
    date/0, time/0, datetime/0,
    instant/0, duration/0,
    unit/0, unit_spec/0,
    offset/0, time_unit/0,
    error_reason/0, compare/0
]).

-export([date/1, date/3, time/1, time/3, time/4, datetime/1, datetime/2]).
-export([instant/0, instant/2, now/0, duration/1]).
-export([year/1, month/1, day/1, hour/1, minute/1, second/1,
         time_microsecond/1, to_microseconds/1]).
-export([to_date/1, to_time/1]).
-export([is_date/1, is_time/1, is_datetime/1, is_instant/1, is_duration/1]).
-export([is_leap_year/1, days_in_month/1, days_in_month/2,
         day_of_week/1, iso_week/1]).
-export([to_otp_date/1, to_otp_time/1, to_otp_datetime/1,
         from_system_time/2, to_system_time/2,
         from_timestamp/1, to_timestamp/1]).
-export([to_instant/2, from_instant/2]).
-export([utc_datetime/0]).
-export([add_date/2, add_datetime/2, add_instant/2, add_duration/2]).
-export([subtract_date/2, subtract_datetime/2, subtract_instant/2, subtract_duration/2]).
-export([diff_date/2, diff_datetime/2, diff_time/2, diff_instant/2, diff_duration/2]).
-export([negate/1]).
-export([compare/2, min/2, max/2]).
-export([format/1, format/2,
         parse_date/1, parse_time/1, parse_datetime/1,
         parse_rfc3339/1, parse_duration/1]).

-define(UNIX_EPOCH_GREGORIAN_SECONDS, 62167219200).
-define(MICROS_PER_SECOND, 1000000).
-define(MICROS_PER_MINUTE, 60000000).
-define(MICROS_PER_HOUR, 3600000000).
-define(MICROS_PER_DAY, 86400000000).
-define(MAX_OFFSET_SECONDS, 86400).

-doc "Gregorian year in `0..9999`.".
-type year() :: 0..9999.
-doc "ISO week-year; it may be `-1` for civil year 0.".
-type iso_week_year() :: -1..9999.
-doc "Gregorian month in `1..12`.".
-type month() :: 1..12.
-doc "Gregorian day of month in `1..31`.".
-type day() :: 1..31.
-doc "Hour of day in `0..23`.".
-type hour() :: 0..23.
-doc "Minute in `0..59`.".
-type minute() :: 0..59.
-doc "Second in `0..59`. Leap seconds are not represented.".
-type second() :: 0..59.
-doc "Microsecond fraction of a second in `0..999999`.".
-type frac_microsecond() :: 0..999999.

-doc "Civil date `{date, Year, Month, Day}`.".
-type date() :: {date, year(), month(), day()}.
-doc "Time of day `{time, Hour, Minute, Second, Microsecond}`.".
-type time() :: {time, hour(), minute(), second(), frac_microsecond()}.
-doc "Naive datetime `{datetime, Date, Time}`.".
-type datetime() :: {datetime, date(), time()}.
-doc "POSIX instant `{instant, Microseconds}` since 1970-01-01T00:00:00Z.".
-type instant() :: {instant, integer()}.
-doc "Exact elapsed time `{duration, Microseconds}`.".
-type duration() :: {duration, integer()}.

-doc "Duration unit atom. `day` is 86400 seconds; `week` is 7 days.".
-type unit() ::
    nanosecond | microsecond | millisecond | second |
    minute | hour | day | week.

-doc "Tagged duration input `{Unit, Count}`.".
-type unit_spec() :: {unit(), integer()}.

-doc "Seconds east of UTC, minute-aligned, in `-86400..86400`, or `utc`.".
-type offset() :: utc | {offset, integer()}.

-doc "OTP-style time unit used by instants and `system_time`.".
-type time_unit() :: nanosecond | microsecond | millisecond | second.

-doc "Reason atom from constructors and parsers.".
-type error_reason() ::
    invalid_date |
    invalid_time |
    invalid_datetime |
    invalid_duration |
    invalid_format |
    out_of_range.

-doc "Ordering result of `compare/2`.".
-type compare() :: lt | eq | gt.

%%--------------------------------------------------------------------
%% Constructors
%%--------------------------------------------------------------------

-doc """
Construct a Gregorian date from an OTP `{Year, Month, Day}` tuple or a tagged date.

It re-validates a tagged value and rejects years outside `0..9999`.
""".
-spec date(calendar:date() | date()) -> {ok, date()} | {error, invalid_date}.
date({date, Y, M, D}) ->
    date(Y, M, D);
date({Y, M, D}) when is_integer(Y), is_integer(M), is_integer(D) ->
    date(Y, M, D);
date(_) ->
    {error, invalid_date}.

-doc """
Construct a Gregorian date from year, month, and day.

It returns `{error, invalid_date}` when the civil date does not exist or the
year is outside `0..9999`.
""".
-spec date(year(), month(), day()) -> {ok, date()} | {error, invalid_date}.
date(Y, M, D) when is_integer(Y), is_integer(M), is_integer(D) ->
    case Y >= 0 andalso Y =< 9999 andalso calendar:valid_date(Y, M, D) of
        true -> {ok, {date, Y, M, D}};
        false -> {error, invalid_date}
    end;
date(_, _, _) ->
    {error, invalid_date}.

-doc """
Construct a time of day from an OTP `{Hour, Minute, Second}` tuple or a tagged time.

OTP tuples get a zero microsecond field.
""".
-spec time(calendar:time() | time()) -> {ok, time()} | {error, invalid_time}.
time({time, H, Min, S, Us}) ->
    time(H, Min, S, Us);
time({H, Min, S}) when is_integer(H), is_integer(Min), is_integer(S) ->
    time(H, Min, S, 0);
time(_) ->
    {error, invalid_time}.

-doc "Construct a time of day with a zero microsecond field.".
-spec time(hour(), minute(), second()) -> {ok, time()} | {error, invalid_time}.
time(H, Min, S) ->
    time(H, Min, S, 0).

-doc """
Construct a time of day including microseconds.

It rejects `24:00:00` and `23:59:60`.
""".
-spec time(hour(), minute(), second(), frac_microsecond()) ->
    {ok, time()} | {error, invalid_time}.
time(H, Min, S, Us)
  when is_integer(H), is_integer(Min), is_integer(S), is_integer(Us) ->
    case H >= 0 andalso H =< 23
         andalso Min >= 0 andalso Min =< 59
         andalso S >= 0 andalso S =< 59
         andalso Us >= 0 andalso Us =< 999999 of
        true -> {ok, {time, H, Min, S, Us}};
        false -> {error, invalid_time}
    end;
time(_, _, _, _) ->
    {error, invalid_time}.

-doc """
Construct a naive datetime from an OTP `{{Y,M,D},{H,Min,S}}` tuple or a tagged datetime.
""".
-spec datetime(calendar:datetime() | datetime()) ->
    {ok, datetime()} | {error, invalid_datetime}.
datetime({datetime, Date, Time}) ->
    datetime(Date, Time);
datetime({{Y, M, D}, {H, Min, S}}) ->
    case date(Y, M, D) of
        {ok, Date} ->
            case time(H, Min, S) of
                {ok, Time} -> {ok, {datetime, Date, Time}};
                {error, _} -> {error, invalid_datetime}
            end;
        {error, _} ->
            {error, invalid_datetime}
    end;
datetime(_) ->
    {error, invalid_datetime}.

-doc """
Construct a naive datetime from a tagged date and time.

Both parts must be civil-valid.
""".
-spec datetime(date(), time()) -> {ok, datetime()} | {error, invalid_datetime}.
datetime(Date, Time) ->
    case is_date(Date) andalso is_time(Time) of
        true -> {ok, {datetime, Date, Time}};
        false -> {error, invalid_datetime}
    end.

-doc """
Return the current POSIX instant.

It is `erlang:system_time(microsecond)`, never local wall time.
""".
-spec instant() -> instant().
instant() ->
    {instant, erlang:system_time(microsecond)}.

-doc """
Construct an instant from an integer in the given time unit.

It always succeeds for a well-typed integer and unit. Conversion from a
finer unit floors.
""".
-spec instant(integer(), time_unit()) -> instant().
instant(N, nanosecond) when is_integer(N) ->
    {instant, erlang:convert_time_unit(N, nanosecond, microsecond)};
instant(N, microsecond) when is_integer(N) ->
    {instant, N};
instant(N, millisecond) when is_integer(N) ->
    {instant, N * 1000};
instant(N, second) when is_integer(N) ->
    {instant, N * ?MICROS_PER_SECOND};
instant(_, _) ->
    erlang:error(badarg).

-doc """
Alias of `instant/0`.

It is not `erlang:now/0`.
""".
-spec now() -> instant().
now() ->
    instant().

-doc """
Construct a duration from a unit tag, a list of unit tags, or a tagged duration.

Unit atoms are singular (`hour`, not `hours`). `{month, _}` and `{year, _}`
are `{error, invalid_duration}`.
""".
-spec duration(unit_spec() | [unit_spec()] | duration()) ->
    {ok, duration()} | {error, invalid_duration}.
duration({duration, Us}) when is_integer(Us) ->
    {ok, {duration, Us}};
duration(List) when is_list(List) ->
    duration_sum(List, 0);
duration(Spec) ->
    case unit_spec_to_us(Spec) of
        {ok, Us} -> {ok, {duration, Us}};
        error -> {error, invalid_duration}
    end.

%%--------------------------------------------------------------------
%% Accessors
%%--------------------------------------------------------------------

-doc "Year field of a date or datetime.".
-spec year(date() | datetime()) -> year().
year({date, Y, _, _} = Date) ->
    require(is_date(Date)),
    Y;
year({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    year(to_date(DT));
year(_) ->
    erlang:error(badarg).

-doc "Month field of a date or datetime.".
-spec month(date() | datetime()) -> month().
month({date, _, M, _} = Date) ->
    require(is_date(Date)),
    M;
month({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    month(to_date(DT));
month(_) ->
    erlang:error(badarg).

-doc "Day field of a date or datetime.".
-spec day(date() | datetime()) -> day().
day({date, _, _, D} = Date) ->
    require(is_date(Date)),
    D;
day({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    day(to_date(DT));
day(_) ->
    erlang:error(badarg).

-doc "Hour field of a time or datetime.".
-spec hour(time() | datetime()) -> hour().
hour({time, H, _, _, _} = Time) ->
    require(is_time(Time)),
    H;
hour({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    hour(to_time(DT));
hour(_) ->
    erlang:error(badarg).

-doc "Minute field of a time or datetime.".
-spec minute(time() | datetime()) -> minute().
minute({time, _, Min, _, _} = Time) ->
    require(is_time(Time)),
    Min;
minute({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    minute(to_time(DT));
minute(_) ->
    erlang:error(badarg).

-doc "Second field of a time or datetime.".
-spec second(time() | datetime()) -> second().
second({time, _, _, S, _} = Time) ->
    require(is_time(Time)),
    S;
second({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    second(to_time(DT));
second(_) ->
    erlang:error(badarg).

-doc "Microsecond field of a time or datetime, in `0..999999`.".
-spec time_microsecond(time() | datetime()) -> frac_microsecond().
time_microsecond({time, _, _, _, Us} = Time) ->
    require(is_time(Time)),
    Us;
time_microsecond({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    time_microsecond(to_time(DT));
time_microsecond(_) ->
    erlang:error(badarg).

-doc "Underlying microsecond integer of an instant or duration.".
-spec to_microseconds(instant() | duration()) -> integer().
to_microseconds({instant, Us} = Inst) ->
    require(is_instant(Inst)),
    Us;
to_microseconds({duration, Us} = Dur) ->
    require(is_duration(Dur)),
    Us;
to_microseconds(_) ->
    erlang:error(badarg).

-doc "Date part of a naive datetime.".
-spec to_date(datetime()) -> date().
to_date({datetime, Date, _} = DT) ->
    require(is_datetime(DT)),
    Date;
to_date(_) ->
    erlang:error(badarg).

-doc "Time part of a naive datetime.".
-spec to_time(datetime()) -> time().
to_time({datetime, _, Time} = DT) ->
    require(is_datetime(DT)),
    Time;
to_time(_) ->
    erlang:error(badarg).

%%--------------------------------------------------------------------
%% Predicates
%%--------------------------------------------------------------------

-doc "Return true when the term is a civil-valid tagged date.".
-spec is_date(term()) -> boolean().
is_date({date, Y, M, D})
  when is_integer(Y), Y >= 0, Y =< 9999,
       is_integer(M), is_integer(D) ->
    calendar:valid_date(Y, M, D);
is_date(_) ->
    false.

-doc "Return true when the term is a civil-valid tagged time.".
-spec is_time(term()) -> boolean().
is_time({time, H, Min, S, Us})
  when is_integer(H), H >= 0, H =< 23,
       is_integer(Min), Min >= 0, Min =< 59,
       is_integer(S), S >= 0, S =< 59,
       is_integer(Us), Us >= 0, Us =< 999999 ->
    true;
is_time(_) ->
    false.

-doc "Return true when the term is a tagged datetime with valid parts.".
-spec is_datetime(term()) -> boolean().
is_datetime({datetime, Date, Time}) ->
    is_date(Date) andalso is_time(Time);
is_datetime(_) ->
    false.

-doc "Return true when the term is `{instant, Integer}`.".
-spec is_instant(term()) -> boolean().
is_instant({instant, Us}) when is_integer(Us) ->
    true;
is_instant(_) ->
    false.

-doc "Return true when the term is `{duration, Integer}`.".
-spec is_duration(term()) -> boolean().
is_duration({duration, Us}) when is_integer(Us) ->
    true;
is_duration(_) ->
    false.

%%--------------------------------------------------------------------
%% Calendar facts
%%--------------------------------------------------------------------

-doc "Return whether the year is a Gregorian leap year.".
-spec is_leap_year(year() | date() | datetime()) -> boolean().
is_leap_year({date, _, _, _} = Date) ->
    require(is_date(Date)),
    calendar:is_leap_year(year(Date));
is_leap_year({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    calendar:is_leap_year(year(DT));
is_leap_year(Y) when is_integer(Y) ->
    calendar:is_leap_year(Y);
is_leap_year(_) ->
    erlang:error(badarg).

-doc "Number of days in the month of a date or datetime.".
-spec days_in_month(date() | datetime()) -> 28..31.
days_in_month({date, Y, M, _} = Date) ->
    require(is_date(Date)),
    days_in_month(Y, M);
days_in_month({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    days_in_month(to_date(DT));
days_in_month(_) ->
    erlang:error(badarg).

-doc """
Number of days in a year/month pair.

Month outside `1..12` is `badarg`.
""".
-spec days_in_month(year(), month()) -> 28..31.
days_in_month(Y, M) when is_integer(Y), is_integer(M) ->
    wrap_otp(fun() -> calendar:last_day_of_the_month(Y, M) end);
days_in_month(_, _) ->
    erlang:error(badarg).

-doc "ISO day of week, `1` = Monday.".
-spec day_of_week(date() | datetime()) -> 1..7.
day_of_week({date, Y, M, D} = Date) ->
    require(is_date(Date)),
    wrap_otp(fun() -> calendar:day_of_the_week(Y, M, D) end);
day_of_week({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    day_of_week(to_date(DT));
day_of_week(_) ->
    erlang:error(badarg).

-doc """
ISO week number `{WeekYear, Week}`.

Week-year can differ from the civil year, including `-1` for `{date, 0, 1, 1}`.
""".
-spec iso_week(date() | datetime()) -> {iso_week_year(), 1..53}.
iso_week({date, Y, M, D} = Date) ->
    require(is_date(Date)),
    G = wrap_otp(fun() -> calendar:date_to_gregorian_days(Y, M, D) end),
    Dow = wrap_otp(fun() -> calendar:day_of_the_week(Y, M, D) end),
    iso_week_from_thursday(G + (4 - Dow));
iso_week({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    iso_week(to_date(DT));
iso_week(_) ->
    erlang:error(badarg).

%%--------------------------------------------------------------------
%% OTP interop
%%--------------------------------------------------------------------

-doc "Export a tagged date as an OTP `{Year, Month, Day}` tuple.".
-spec to_otp_date(date()) -> calendar:date().
to_otp_date({date, Y, M, D} = Date) ->
    require(is_date(Date)),
    {Y, M, D};
to_otp_date(_) ->
    erlang:error(badarg).

-doc "Export a tagged time as an OTP `{Hour, Minute, Second}` tuple, dropping microseconds.".
-spec to_otp_time(time()) -> calendar:time().
to_otp_time({time, H, Min, S, _} = Time) ->
    require(is_time(Time)),
    {H, Min, S};
to_otp_time(_) ->
    erlang:error(badarg).

-doc "Export a tagged datetime as an OTP datetime tuple, dropping microseconds.".
-spec to_otp_datetime(datetime()) -> calendar:datetime().
to_otp_datetime({datetime, Date, Time} = DT) ->
    require(is_datetime(DT)),
    {to_otp_date(Date), to_otp_time(Time)};
to_otp_datetime(_) ->
    erlang:error(badarg).

-doc "Construct an instant from `erlang:system_time/1` units. Same as `instant/2`.".
-spec from_system_time(integer(), time_unit()) -> instant().
from_system_time(N, Unit) ->
    instant(N, Unit).

-doc """
Convert an instant to an integer in the given time unit.

Coarser units floor, including for negative instants.
""".
-spec to_system_time(instant(), time_unit()) -> integer().
to_system_time({instant, Us} = Inst, nanosecond) ->
    require(is_instant(Inst)),
    Us * 1000;
to_system_time({instant, Us} = Inst, microsecond) ->
    require(is_instant(Inst)),
    Us;
to_system_time({instant, Us} = Inst, millisecond) ->
    require(is_instant(Inst)),
    {Q, _} = floor_div(Us, 1000),
    Q;
to_system_time({instant, Us} = Inst, second) ->
    require(is_instant(Inst)),
    {Q, _} = floor_div(Us, ?MICROS_PER_SECOND),
    Q;
to_system_time(_, _) ->
    erlang:error(badarg).

-doc "Construct an instant from an `erlang:timestamp/0` triple.".
-spec from_timestamp(erlang:timestamp()) -> instant().
from_timestamp({Mega, Sec, Micro})
  when is_integer(Mega), Mega >= 0,
       is_integer(Sec), Sec >= 0,
       is_integer(Micro), Micro >= 0 ->
    {instant, Mega * 1000000000000 + Sec * ?MICROS_PER_SECOND + Micro};
from_timestamp(_) ->
    erlang:error(badarg).

-doc """
Export an instant as `erlang:timestamp/0`.

Instants before 1970 raise `out_of_range`.
""".
-spec to_timestamp(instant()) -> erlang:timestamp().
to_timestamp({instant, Us} = Inst) ->
    require(is_instant(Inst)),
    case Us < 0 of
        true ->
            erlang:error(out_of_range);
        false ->
            Mega = Us div 1000000000000,
            Rest = Us rem 1000000000000,
            {Mega, Rest div ?MICROS_PER_SECOND, Rest rem ?MICROS_PER_SECOND}
    end;
to_timestamp(_) ->
    erlang:error(badarg).

%%--------------------------------------------------------------------
%% Instant <-> datetime
%%--------------------------------------------------------------------

-doc """
Convert a naive datetime to an instant using an explicit offset.

`utc` is offset 0. `{offset, Seconds}` must be minute-aligned and in
`-86400..86400`.
""".
-spec to_instant(datetime(), offset()) -> instant().
to_instant(DT, Offset) ->
    require(is_datetime(DT)),
    OffsetUs = offset_seconds(Offset) * ?MICROS_PER_SECOND,
    {instant, datetime_to_civil_us(DT)
              - (?UNIX_EPOCH_GREGORIAN_SECONDS * ?MICROS_PER_SECOND)
              - OffsetUs}.

-doc """
Project an instant to a naive datetime using an explicit offset.

Civil years outside `0..9999` raise `out_of_range`.
""".
-spec from_instant(instant(), offset()) -> datetime().
from_instant(Inst, Offset) ->
    require(is_instant(Inst)),
    {instant, UnixUs} = Inst,
    OffsetUs = offset_seconds(Offset) * ?MICROS_PER_SECOND,
    CivilUs = UnixUs + OffsetUs
              + (?UNIX_EPOCH_GREGORIAN_SECONDS * ?MICROS_PER_SECOND),
    civil_us_to_datetime(CivilUs).

-doc "Current UTC naive datetime, from `instant/0`.".
-spec utc_datetime() -> datetime().
utc_datetime() ->
    from_instant(instant(), utc).

%%--------------------------------------------------------------------
%% Arithmetic
%%--------------------------------------------------------------------

-doc """
Add a whole-day duration to a date.

The duration must be an exact multiple of 86400 seconds, otherwise `badarg`.
""".
-spec add_date(date(), duration()) -> date().
add_date(Date, Dur) ->
    require(is_date(Date) andalso is_duration(Dur)),
    {date, Y, M, D} = Date,
    {duration, Us} = Dur,
    case Us rem ?MICROS_PER_DAY of
        0 ->
            Days = Us div ?MICROS_PER_DAY,
            G = wrap_otp(fun() -> calendar:date_to_gregorian_days(Y, M, D) end),
            gregorian_days_to_civil_date(G + Days);
        _ ->
            erlang:error(badarg)
    end.

-doc "Add a duration to a naive datetime on a 86400 s/day civil line.".
-spec add_datetime(datetime(), duration()) -> datetime().
add_datetime(DT, Dur) ->
    require(is_datetime(DT) andalso is_duration(Dur)),
    {duration, D} = Dur,
    civil_us_to_datetime(datetime_to_civil_us(DT) + D).

-doc "Add a duration to an instant.".
-spec add_instant(instant(), duration()) -> instant().
add_instant(Inst, Dur) ->
    require(is_instant(Inst) andalso is_duration(Dur)),
    {instant, Us} = Inst,
    {duration, D} = Dur,
    {instant, Us + D}.

-doc "Add two durations.".
-spec add_duration(duration(), duration()) -> duration().
add_duration(A, B) ->
    require(is_duration(A) andalso is_duration(B)),
    {duration, X} = A,
    {duration, Y} = B,
    {duration, X + Y}.

-doc "Subtract a whole-day duration from a date.".
-spec subtract_date(date(), duration()) -> date().
subtract_date(Date, Dur) ->
    add_date(Date, negate(Dur)).

-doc "Subtract a duration from a naive datetime.".
-spec subtract_datetime(datetime(), duration()) -> datetime().
subtract_datetime(DT, Dur) ->
    add_datetime(DT, negate(Dur)).

-doc "Subtract a duration from an instant.".
-spec subtract_instant(instant(), duration()) -> instant().
subtract_instant(Inst, Dur) ->
    add_instant(Inst, negate(Dur)).

-doc "Subtract two durations.".
-spec subtract_duration(duration(), duration()) -> duration().
subtract_duration(A, B) ->
    add_duration(A, negate(B)).

-doc "Difference of two dates as a whole-day duration.".
-spec diff_date(date(), date()) -> duration().
diff_date(A, B) ->
    require(is_date(A) andalso is_date(B)),
    {date, Y1, M1, D1} = A,
    {date, Y2, M2, D2} = B,
    G1 = wrap_otp(fun() -> calendar:date_to_gregorian_days(Y1, M1, D1) end),
    G2 = wrap_otp(fun() -> calendar:date_to_gregorian_days(Y2, M2, D2) end),
    {duration, (G1 - G2) * ?MICROS_PER_DAY}.

-doc "Difference of two naive datetimes as a duration.".
-spec diff_datetime(datetime(), datetime()) -> duration().
diff_datetime(A, B) ->
    require(is_datetime(A) andalso is_datetime(B)),
    {duration, datetime_to_civil_us(A) - datetime_to_civil_us(B)}.

-doc """
Difference of two times of day as a signed duration.

It does not wrap at midnight. There is no `add` on `time()`.
""".
-spec diff_time(time(), time()) -> duration().
diff_time(A, B) ->
    require(is_time(A) andalso is_time(B)),
    {duration, time_to_us(A) - time_to_us(B)}.

-doc "Difference of two instants as a duration.".
-spec diff_instant(instant(), instant()) -> duration().
diff_instant(A, B) ->
    require(is_instant(A) andalso is_instant(B)),
    {instant, X} = A,
    {instant, Y} = B,
    {duration, X - Y}.

-doc "Difference of two durations.".
-spec diff_duration(duration(), duration()) -> duration().
diff_duration(A, B) ->
    require(is_duration(A) andalso is_duration(B)),
    {duration, X} = A,
    {duration, Y} = B,
    {duration, X - Y}.

-doc "Negate a duration.".
-spec negate(duration()) -> duration().
negate({duration, Us} = Dur) ->
    require(is_duration(Dur)),
    {duration, -Us};
negate(_) ->
    erlang:error(badarg).

%%--------------------------------------------------------------------
%% Comparison
%%--------------------------------------------------------------------

-doc "Compare two values of the same type. Mixed types are `badarg`.".
-spec compare(date(), date()) -> compare()
      ;      (time(), time()) -> compare()
      ;      (datetime(), datetime()) -> compare()
      ;      (instant(), instant()) -> compare()
      ;      (duration(), duration()) -> compare().
compare({date, _, _, _} = A, {date, _, _, _} = B) ->
    require(is_date(A) andalso is_date(B)),
    cmp(A, B);
compare({time, _, _, _, _} = A, {time, _, _, _, _} = B) ->
    require(is_time(A) andalso is_time(B)),
    cmp(A, B);
compare({datetime, _, _} = A, {datetime, _, _} = B) ->
    require(is_datetime(A) andalso is_datetime(B)),
    cmp(A, B);
compare({instant, _} = A, {instant, _} = B) ->
    require(is_instant(A) andalso is_instant(B)),
    cmp(A, B);
compare({duration, _} = A, {duration, _} = B) ->
    require(is_duration(A) andalso is_duration(B)),
    cmp(A, B);
compare(_, _) ->
    erlang:error(badarg).

-doc "Lesser of two same-typed values according to `compare/2`.".
-spec min(T, T) -> T when T :: date() | time() | datetime() | instant() | duration().
min(A, B) ->
    case compare(A, B) of
        gt -> B;
        _ -> A
    end.

-doc "Greater of two same-typed values according to `compare/2`.".
-spec max(T, T) -> T when T :: date() | time() | datetime() | instant() | duration().
max(A, B) ->
    case compare(A, B) of
        lt -> B;
        _ -> A
    end.

%%--------------------------------------------------------------------
%% Format / parse
%%--------------------------------------------------------------------

-doc """
Format a value as ISO 8601 or RFC 3339.

Instants are formatted in UTC. Zero fractions are omitted, so a whole second
instant ends in `Z` rather than `.000000Z`.
""".
-spec format(date() | time() | datetime() | instant() | duration()) -> binary().
format({date, _, _, _} = Date) ->
    require(is_date(Date)),
    format_date(Date);
format({time, _, _, _, _} = Time) ->
    require(is_time(Time)),
    format_time(Time);
format({datetime, _, _} = DT) ->
    require(is_datetime(DT)),
    format_datetime(DT);
format({instant, _} = Inst) ->
    format(Inst, utc);
format({duration, _} = Dur) ->
    require(is_duration(Dur)),
    format_duration(Dur);
format(_) ->
    erlang:error(badarg).

-doc "Format an instant with an explicit offset (`Z` when the offset is 0).".
-spec format(instant(), offset()) -> binary().
format(Inst, Offset) ->
    DT = from_instant(Inst, Offset),
    iolist_to_binary([format_datetime(DT), format_offset(offset_seconds(Offset))]).

-doc "Parse `YYYY-MM-DD`. Five-digit years are `invalid_format`.".
-spec parse_date(binary() | string()) -> {ok, date()} | {error, error_reason()}.
parse_date(Input) ->
    case parse_iso_date(to_bin(Input)) of
        {ok, Y, M, D, <<>>} -> date(Y, M, D);
        {ok, _, _, _, _} -> {error, invalid_format};
        {error, Reason} -> {error, Reason}
    end.

-doc "Parse `HH:MM:SS` with an optional fraction. `.5` is 500000 microseconds.".
-spec parse_time(binary() | string()) -> {ok, time()} | {error, error_reason()}.
parse_time(Input) ->
    case parse_iso_time(to_bin(Input)) of
        {ok, H, Min, S, Us, <<>>} -> time(H, Min, S, Us);
        {ok, _, _, _, _, _} -> {error, invalid_format};
        {error, Reason} -> {error, Reason}
    end.

-doc """
Parse a naive ISO datetime `YYYY-MM-DDTHH:MM:SS`.

An offset (`Z` or `±HH:MM`) is `invalid_format`; use `parse_rfc3339/1`.
""".
-spec parse_datetime(binary() | string()) ->
    {ok, datetime()} | {error, error_reason()}.
parse_datetime(Input) ->
    case parse_naive_datetime(to_bin(Input)) of
        {ok, Date, Time, <<>>} -> datetime(Date, Time);
        {ok, _, _, _} -> {error, invalid_format};
        {error, Reason} -> {error, Reason}
    end.

-doc """
Parse an RFC 3339 timestamp to an instant.

Leap seconds (`23:59:60`) are `invalid_time`. Offset is consumed, not stored.
""".
-spec parse_rfc3339(binary() | string()) ->
    {ok, instant()} | {error, error_reason()}.
parse_rfc3339(Input) ->
    case parse_naive_datetime(to_bin(Input)) of
        {error, Reason} ->
            {error, Reason};
        {ok, Date, Time, Rest} ->
            case parse_offset(Rest) of
                {error, Reason} ->
                    {error, Reason};
                {ok, Offset} ->
                    {ok, DT} = datetime(Date, Time),
                    {ok, to_instant(DT, Offset)}
            end
    end.

-doc """
Parse an ISO 8601 duration.

Fraction is allowed only on `S`. `P1M` is `invalid_duration`. Format of
`PT24H` is `P1D`.
""".
-spec parse_duration(binary() | string()) ->
    {ok, duration()} | {error, error_reason()}.
parse_duration(Input) ->
    Chars = string:uppercase(binary_to_list(to_bin(Input))),
    {Sign, Body} = case Chars of
        [$- | Rest] -> {-1, Rest};
        _ -> {1, Chars}
    end,
    case duration_body(Body) of
        {ok, Us} -> {ok, {duration, Sign * Us}};
        {error, Reason} -> {error, Reason}
    end.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

require(true) ->
    ok;
require(false) ->
    erlang:error(badarg).

wrap_otp(Fun) ->
    try Fun()
    catch
        error:function_clause -> erlang:error(badarg);
        error:badarg -> erlang:error(badarg)
    end.

floor_div(A, B) when B > 0 ->
    Q = A div B,
    R = A rem B,
    case R < 0 of
        true -> {Q - 1, R + B};
        false -> {Q, R}
    end.

datetime_to_civil_us(DT) ->
    require(is_datetime(DT)),
    {datetime, {date, Y, M, D}, {time, H, Min, S, Us}} = DT,
    G = wrap_otp(fun() -> calendar:datetime_to_gregorian_seconds({{Y, M, D}, {H, Min, S}}) end),
    G * ?MICROS_PER_SECOND + Us.

civil_us_to_datetime(CivilUs) ->
    {G, Us} = floor_div(CivilUs, ?MICROS_PER_SECOND),
    try calendar:gregorian_seconds_to_datetime(G) of
        {{Y, M, D}, {H, Min, S}} when Y >= 0, Y =< 9999 ->
            {datetime, {date, Y, M, D}, {time, H, Min, S, Us}};
        {{_, _, _}, {_, _, _}} ->
            erlang:error(out_of_range)
    catch
        error:badarg -> erlang:error(out_of_range);
        error:function_clause -> erlang:error(out_of_range)
    end.

gregorian_days_to_civil_date(G) ->
    try calendar:gregorian_days_to_date(G) of
        {Y, M, D} when Y >= 0, Y =< 9999 ->
            {date, Y, M, D};
        {_, _, _} ->
            erlang:error(out_of_range)
    catch
        error:badarg -> erlang:error(out_of_range);
        error:function_clause -> erlang:error(out_of_range)
    end.

% OTP 27/28 `calendar` rejects year -1, so ISO week is computed from the week's Thursday.
iso_week_from_thursday(ThursdayG) ->
    {WeekYear, Jan4G} = iso_week_year_and_jan4(ThursdayG),
    Week1ThursdayG = Jan4G + (4 - dow_at(Jan4G)),
    {WeekYear, (ThursdayG - Week1ThursdayG) div 7 + 1}.

iso_week_year_and_jan4(ThursdayG) when ThursdayG < 0 ->
    {-1, 3 - gregorian_year_length(-1)};
iso_week_year_and_jan4(ThursdayG) ->
    {date, TY, _, _} = gregorian_days_to_civil_date(ThursdayG),
    Jan4G = wrap_otp(fun() -> calendar:date_to_gregorian_days(TY, 1, 4) end),
    {TY, Jan4G}.

dow_at(G) when G >= 0 ->
    {Y, M, D} = wrap_otp(fun() -> calendar:gregorian_days_to_date(G) end),
    wrap_otp(fun() -> calendar:day_of_the_week(Y, M, D) end);
dow_at(G) ->
    D0 = wrap_otp(fun() -> calendar:day_of_the_week(0, 1, 1) end),
    ((D0 - 1 + G) rem 7 + 7) rem 7 + 1.

gregorian_year_length(Y) when Y rem 4 =:= 0, Y rem 100 =/= 0 -> 366;
gregorian_year_length(Y) when Y rem 400 =:= 0 -> 366;
gregorian_year_length(_) -> 365.

time_to_us({time, H, Min, S, Us} = Time) ->
    require(is_time(Time)),
    ((H * 3600 + Min * 60 + S) * ?MICROS_PER_SECOND) + Us.

offset_seconds(utc) ->
    0;
offset_seconds({offset, Seconds})
  when is_integer(Seconds),
       Seconds rem 60 =:= 0,
       Seconds >= -?MAX_OFFSET_SECONDS,
       Seconds =< ?MAX_OFFSET_SECONDS ->
    Seconds;
offset_seconds(_) ->
    erlang:error(badarg).

format_offset(0) ->
    <<"Z">>;
format_offset(Seconds) ->
    Sign = case Seconds < 0 of true -> <<"-">>; false -> <<"+">> end,
    Abs = abs(Seconds),
    Hours = Abs div 3600,
    Mins = (Abs rem 3600) div 60,
    iolist_to_binary(io_lib:format("~s~2.10.0B:~2.10.0B", [Sign, Hours, Mins])).

cmp(A, B) when A < B -> lt;
cmp(A, B) when A > B -> gt;
cmp(A, B) when A =:= B -> eq.

unit_spec_to_us({nanosecond, N}) when is_integer(N) ->
    {ok, erlang:convert_time_unit(N, nanosecond, microsecond)};
unit_spec_to_us({microsecond, N}) when is_integer(N) ->
    {ok, N};
unit_spec_to_us({millisecond, N}) when is_integer(N) ->
    {ok, N * 1000};
unit_spec_to_us({second, N}) when is_integer(N) ->
    {ok, N * ?MICROS_PER_SECOND};
unit_spec_to_us({minute, N}) when is_integer(N) ->
    {ok, N * ?MICROS_PER_MINUTE};
unit_spec_to_us({hour, N}) when is_integer(N) ->
    {ok, N * ?MICROS_PER_HOUR};
unit_spec_to_us({day, N}) when is_integer(N) ->
    {ok, N * ?MICROS_PER_DAY};
unit_spec_to_us({week, N}) when is_integer(N) ->
    {ok, N * 7 * ?MICROS_PER_DAY};
unit_spec_to_us(_) ->
    error.

duration_sum([], Acc) ->
    {ok, {duration, Acc}};
duration_sum([H | T], Acc) ->
    case unit_spec_to_us(H) of
        {ok, Us} -> duration_sum(T, Acc + Us);
        error -> {error, invalid_duration}
    end;
duration_sum(_, _) ->
    {error, invalid_duration}.

frac_to_us(Digits) ->
    Six = lists:sublist(Digits, 6),
    Padded = Six ++ lists:duplicate(6 - length(Six), $0),
    list_to_integer(Padded).

trim_frac(0) ->
    <<>>;
trim_frac(Us) ->
    Digits = lists:flatten(io_lib:format("~6.10.0B", [Us])),
    Stripped = lists:reverse(lists:dropwhile(fun(C) -> C =:= $0 end, lists:reverse(Digits))),
    list_to_binary([$. | Stripped]).

format_date({date, Y, M, D}) ->
    iolist_to_binary(io_lib:format("~4.10.0B-~2.10.0B-~2.10.0B", [Y, M, D])).

format_time({time, H, Min, S, Us}) ->
    iolist_to_binary([
        io_lib:format("~2.10.0B:~2.10.0B:~2.10.0B", [H, Min, S]),
        trim_frac(Us)
    ]).

format_datetime({datetime, Date, Time}) ->
    iolist_to_binary([format_date(Date), $T, format_time(Time)]).

format_duration({duration, 0}) ->
    <<"PT0S">>;
format_duration({duration, Us}) ->
    Sign = case Us < 0 of true -> <<"-">>; false -> <<>> end,
    Abs = abs(Us),
    Days = Abs div ?MICROS_PER_DAY,
    R1 = Abs rem ?MICROS_PER_DAY,
    Hours = R1 div ?MICROS_PER_HOUR,
    R2 = R1 rem ?MICROS_PER_HOUR,
    Minutes = R2 div ?MICROS_PER_MINUTE,
    R3 = R2 rem ?MICROS_PER_MINUTE,
    Seconds = R3 div ?MICROS_PER_SECOND,
    Micros = R3 rem ?MICROS_PER_SECOND,
    DatePart = case Days of
        0 -> [];
        _ -> [integer_to_list(Days), $D]
    end,
    TimePart = case Hours =:= 0 andalso Minutes =:= 0
                    andalso Seconds =:= 0 andalso Micros =:= 0 of
        true -> [];
        false ->
            [$T, maybe_unit(Hours, $H), maybe_unit(Minutes, $M),
             maybe_seconds(Seconds, Micros)]
    end,
    iolist_to_binary([Sign, $P, DatePart, TimePart]).

maybe_unit(0, _) -> [];
maybe_unit(N, U) -> [integer_to_list(N), U].

maybe_seconds(0, 0) -> [];
maybe_seconds(S, 0) -> [integer_to_list(S), $S];
maybe_seconds(S, Us) -> [integer_to_list(S), trim_frac(Us), $S].

to_bin(Bin) when is_binary(Bin) ->
    Bin;
to_bin(List) when is_list(List) ->
    case io_lib:char_list(List) of
        true ->
            case unicode:characters_to_binary(List) of
                Bin when is_binary(Bin) -> Bin;
                _ -> erlang:error(badarg)
            end;
        false ->
            erlang:error(badarg)
    end;
to_bin(_) ->
    erlang:error(badarg).

d2(A, B) when A >= $0, A =< $9, B >= $0, B =< $9 ->
    {ok, (A - $0) * 10 + (B - $0)};
d2(_, _) ->
    error.

d4(A, B, C, D)
  when A >= $0, A =< $9, B >= $0, B =< $9,
       C >= $0, C =< $9, D >= $0, D =< $9 ->
    {ok, (A - $0) * 1000 + (B - $0) * 100 + (C - $0) * 10 + (D - $0)};
d4(_, _, _, _) ->
    error.

parse_iso_date(<<Y1, Y2, Y3, Y4, $-, Mo1, Mo2, $-, D1, D2, Rest/binary>>) ->
    case {d4(Y1, Y2, Y3, Y4), d2(Mo1, Mo2), d2(D1, D2)} of
        {{ok, Y}, {ok, Mo}, {ok, D}} -> {ok, Y, Mo, D, Rest};
        _ -> {error, invalid_format}
    end;
parse_iso_date(_) ->
    {error, invalid_format}.

parse_iso_time(<<H1, H2, $:, M1, M2, $:, S1, S2, Rest0/binary>>) ->
    case {d2(H1, H2), d2(M1, M2), d2(S1, S2)} of
        {{ok, H}, {ok, Min}, {ok, S}} ->
            case parse_frac(Rest0) of
                {ok, Us, Rest} -> {ok, H, Min, S, Us, Rest};
                {error, Reason} -> {error, Reason}
            end;
        _ ->
            {error, invalid_format}
    end;
parse_iso_time(_) ->
    {error, invalid_format}.

parse_frac(<<$., Rest/binary>>) ->
    take_frac_digits(Rest, []);
parse_frac(Rest) ->
    {ok, 0, Rest}.

take_frac_digits(<<C, Rest/binary>>, Acc) when C >= $0, C =< $9 ->
    take_frac_digits(Rest, [C | Acc]);
take_frac_digits(_Rest, []) ->
    {error, invalid_format};
take_frac_digits(Rest, Acc) ->
    {ok, frac_to_us(lists:reverse(Acc)), Rest}.

parse_sep(<<C, Rest/binary>>) when C =:= $T; C =:= $t; C =:= $\s ->
    {ok, Rest};
parse_sep(_) ->
    {error, invalid_format}.

parse_naive_datetime(Bin) ->
    case parse_iso_date(Bin) of
        {error, Reason} ->
            {error, Reason};
        {ok, Y, M, D, Rest1} ->
            case parse_sep(Rest1) of
                {error, Reason} ->
                    {error, Reason};
                {ok, Rest2} ->
                    case parse_iso_time(Rest2) of
                        {error, Reason} ->
                            {error, Reason};
                        {ok, H, Min, S, Us, Rest3} ->
                            case S of
                                60 ->
                                    {error, invalid_time};
                                _ ->
                                    case date(Y, M, D) of
                                        {error, invalid_date} ->
                                            {error, invalid_date};
                                        {ok, Date} ->
                                            case time(H, Min, S, Us) of
                                                {error, invalid_time} ->
                                                    {error, invalid_time};
                                                {ok, Time} ->
                                                    {ok, Date, Time, Rest3}
                                            end
                                    end
                            end
                    end
            end
    end.

parse_offset(<<>>) ->
    {error, invalid_format};
parse_offset(<<Z>>) when Z =:= $Z; Z =:= $z ->
    {ok, utc};
parse_offset(<<Sign, H1, H2, Rest/binary>>) when Sign =:= $+; Sign =:= $- ->
    case d2(H1, H2) of
        error ->
            {error, invalid_format};
        {ok, HH} ->
            case parse_offset_minutes(Rest) of
                {error, Reason} ->
                    {error, Reason};
                {ok, MM} ->
                    Seconds0 = HH * 3600 + MM * 60,
                    Seconds = case Sign of
                        $+ -> Seconds0;
                        $- -> -Seconds0
                    end,
                    try offset_seconds({offset, Seconds}) of
                        0 -> {ok, utc};
                        S -> {ok, {offset, S}}
                    catch
                        error:badarg -> {error, invalid_format}
                    end
            end
    end;
parse_offset(_) ->
    {error, invalid_format}.

parse_offset_minutes(<<>>) ->
    {ok, 0};
parse_offset_minutes(<<$:, M1, M2>>) ->
    case d2(M1, M2) of
        {ok, MM} when MM >= 0, MM =< 59 -> {ok, MM};
        _ -> {error, invalid_format}
    end;
parse_offset_minutes(_) ->
    {error, invalid_format}.

duration_body([$P | Rest]) ->
    duration_week_or_parts(Rest);
duration_body(_) ->
    {error, invalid_format}.

duration_week_or_parts([]) ->
    {error, invalid_format};
duration_week_or_parts(S) ->
    case take_int(S) of
        {N, [$W]} ->
            {ok, N * 7 * ?MICROS_PER_DAY};
        {_, [$W | _]} ->
            {error, invalid_format};
        _ ->
            duration_parts(S, 0, false)
    end.

duration_parts(S, Acc, Had) ->
    case take_int(S) of
        {N, [$D | Rest]} ->
            duration_parts(Rest, Acc + N * ?MICROS_PER_DAY, true);
        {_N, [$Y | _]} ->
            {error, invalid_duration};
        {_N, [$M | _]} ->
            {error, invalid_duration};
        {_N, [$. | _]} ->
            {error, invalid_format};
        {_N, _} ->
            {error, invalid_format};
        none ->
            case S of
                [$T | Rest] ->
                    duration_time(Rest, Acc);
                [] when Had ->
                    {ok, Acc};
                [$Y | _] ->
                    {error, invalid_duration};
                [$M | _] ->
                    {error, invalid_duration};
                _ ->
                    {error, invalid_format}
            end
    end.

duration_time(S, Acc) ->
    case duration_opt_unit(S, Acc, $H, ?MICROS_PER_HOUR) of
        {error, Reason} ->
            {error, Reason};
        {ok, Acc1, S1, HadH} ->
            case duration_opt_unit(S1, Acc1, $M, ?MICROS_PER_MINUTE) of
                {error, Reason} ->
                    {error, Reason};
                {ok, Acc2, S2, HadM} ->
                    case duration_opt_s(S2, Acc2) of
                        {error, Reason} ->
                            {error, Reason};
                        {ok, Acc3, S3, HadS} ->
                            case S3 =:= [] andalso (HadH orelse HadM orelse HadS) of
                                true -> {ok, Acc3};
                                false -> {error, invalid_format}
                            end
                    end
            end
    end.

duration_opt_unit(S, Acc, Unit, Mult) ->
    case take_int(S) of
        {N, [U | Rest]} when U =:= Unit ->
            {ok, Acc + N * Mult, Rest, true};
        _ ->
            {ok, Acc, S, false}
    end.

duration_opt_s(S, Acc) ->
    case take_int(S) of
        {N, [$S | Rest]} ->
            {ok, Acc + N * ?MICROS_PER_SECOND, Rest, true};
        {N, [$. | Rest]} ->
            {Digits, After} = take_digit_run(Rest, []),
            case Digits of
                [] ->
                    {error, invalid_format};
                _ ->
                    case After of
                        [$S | Rest2] ->
                            {ok, Acc + N * ?MICROS_PER_SECOND + frac_to_us(Digits), Rest2, true};
                        _ ->
                            {error, invalid_format}
                    end
            end;
        _ ->
            {ok, Acc, S, false}
    end.

take_int(S) ->
    {Digits, Rest} = take_digit_run(S, []),
    case Digits of
        [] -> none;
        _ -> {list_to_integer(Digits), Rest}
    end.

take_digit_run([C | T], Acc) when C >= $0, C =< $9 ->
    take_digit_run(T, [C | Acc]);
take_digit_run(Rest, Acc) ->
    {lists:reverse(Acc), Rest}.
