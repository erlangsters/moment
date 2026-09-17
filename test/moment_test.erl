%%
%% Copyright (c) 2026, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project directory.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(moment_test).
-include_lib("eunit/include/eunit.hrl").

ok_date(Y, M, D) ->
    {ok, Date} = moment:date(Y, M, D),
    Date.

ok_time(H, Min, S) ->
    {ok, Time} = moment:time(H, Min, S),
    Time.

ok_time(H, Min, S, Us) ->
    {ok, Time} = moment:time(H, Min, S, Us),
    Time.

ok_datetime(Date, Time) ->
    {ok, DT} = moment:datetime(Date, Time),
    DT.

ok_duration(Spec) ->
    {ok, Dur} = moment:duration(Spec),
    Dur.

exports_test() ->
    Exports = moment:module_info(exports),
    ?assertNot(lists:member({add, 2}, Exports)),
    ?assertNot(lists:member({from_otp_date, 1}, Exports)),
    ?assertNot(lists:member({from_otp_time, 1}, Exports)),
    ?assertNot(lists:member({from_otp_datetime, 1}, Exports)),
    ?assertNot(lists:member({os_local_datetime, 0}, Exports)),
    ?assertNot(lists:member({moment, 0}, Exports)),
    ?assertNot(lists:member({timezone, 0}, Exports)),
    ?assert(lists:member({add_date, 2}, Exports)),
    ?assert(lists:member({add_datetime, 2}, Exports)),
    ?assert(lists:member({diff_time, 2}, Exports)),
    ?assert(lists:member({instant, 0}, Exports)),
    ?assert(lists:member({now, 0}, Exports)).

invalid_civil_test() ->
    ?assertEqual({error, invalid_date}, moment:date(2023, 2, 29)),
    ?assertEqual({error, invalid_date}, moment:date(1900, 2, 29)),
    ?assertEqual({error, invalid_date}, moment:date(2024, 4, 31)),
    ?assertEqual({error, invalid_date}, moment:date(2024, 13, 1)),
    ?assertEqual({error, invalid_date}, moment:date(2024, 0, 1)),
    ?assertEqual({error, invalid_date}, moment:date(2024, 1, 0)),
    ?assertEqual({error, invalid_date}, moment:date(-1, 1, 1)),
    ?assertEqual({error, invalid_date}, moment:date(10000, 1, 1)),
    ?assertEqual({error, invalid_time}, moment:time(12, 45, 66)),
    ?assertEqual({error, invalid_time}, moment:time(24, 0, 0)),
    ?assertEqual({error, invalid_time}, moment:time(23, 59, 60)),
    ?assertEqual({error, invalid_date}, moment:date({2023, 2, 29})),
    ?assertEqual({error, invalid_time}, moment:time({12, 45, 66})).

valid_civil_test() ->
    ?assertEqual({ok, {date, 2024, 1, 23}}, moment:date(2024, 1, 23)),
    ?assertEqual({ok, {date, 2024, 2, 29}}, moment:date(2024, 2, 29)),
    ?assertEqual({ok, {date, 2000, 2, 29}}, moment:date(2000, 2, 29)),
    ?assertEqual({ok, {date, 0, 2, 29}}, moment:date(0, 2, 29)),
    ?assertEqual({ok, {date, 0, 1, 1}}, moment:date(0, 1, 1)),
    ?assertEqual({ok, {date, 9999, 12, 31}}, moment:date(9999, 12, 31)),
    ?assertEqual({ok, {time, 12, 45, 0, 0}}, moment:time(12, 45, 0)),
    ?assertEqual({ok, {time, 0, 0, 0, 0}}, moment:time(0, 0, 0, 0)),
    ?assertEqual({ok, {time, 23, 59, 59, 999999}}, moment:time(23, 59, 59, 999999)),
    ?assert(moment:is_leap_year(0)),
    ?assert(moment:is_leap_year(ok_date(0, 2, 29))),
    ?assertNot(moment:is_leap_year(1900)),
    ?assert(moment:is_leap_year(2000)),
    ?assert(moment:is_leap_year(2024)),
    ?assertNot(moment:is_leap_year(2023)).

iso_week_test() ->
    ?assertEqual({-1, 52}, moment:iso_week(ok_date(0, 1, 1))),
    ?assertEqual({9998, 53}, moment:iso_week(ok_date(9999, 1, 1))),
    ?assertEqual({9999, 52}, moment:iso_week(ok_date(9999, 12, 31))).

days_in_month_test() ->
    ?assertEqual(29, moment:days_in_month(ok_date(2024, 2, 1))),
    ?assertEqual(28, moment:days_in_month(2023, 2)),
    ?assertError(badarg, moment:days_in_month(2024, 13)).

instant_construct_test() ->
    ?assertEqual({instant, -2}, moment:instant(-1500, nanosecond)),
    ?assertEqual({instant, 1706017500000000}, moment:instant(1706017500, second)),
    Inst = moment:instant(42, microsecond),
    ?assertEqual(Inst, moment:from_system_time(42, microsecond)),
    ?assertEqual(-1, moment:to_system_time({instant, -1}, second)),
    ?assertError(out_of_range, moment:to_timestamp({instant, -1})),
    Ts = {1, 2, 3},
    ?assertEqual(Ts, moment:to_timestamp(moment:from_timestamp(Ts))).

otp_roundtrip_test() ->
    OTPDate = {2024, 1, 23},
    {ok, Date} = moment:date(OTPDate),
    ?assertEqual(OTPDate, moment:to_otp_date(Date)),
    OTPTime = {12, 45, 0},
    {ok, Time} = moment:time(OTPTime),
    ?assertEqual(OTPTime, moment:to_otp_time(Time)),
    {ok, TimeUs} = moment:time(12, 45, 0, 250000),
    ?assertEqual({12, 45, 0}, moment:to_otp_time(TimeUs)),
    OTPDt = {OTPDate, OTPTime},
    {ok, DT} = moment:datetime(OTPDt),
    ?assertEqual(OTPDt, moment:to_otp_datetime(DT)).

date_add_test() ->
    Date = ok_date(2024, 1, 31),
    ?assertEqual(ok_date(2024, 2, 1), moment:add_date(Date, ok_duration({day, 1}))),
    ?assertEqual(ok_date(2024, 2, 1), moment:add_date(Date, ok_duration({second, 86400}))),
    ?assertEqual(ok_date(2024, 2, 1), moment:add_date(Date, ok_duration({hour, 24}))),
    ?assertEqual(ok_date(2024, 2, 7), moment:add_date(Date, ok_duration({week, 1}))),
    ?assertEqual(ok_date(2024, 1, 30), moment:add_date(Date, ok_duration({day, -1}))),
    ?assertError(badarg, moment:add_date(Date, ok_duration({hour, 1}))),
    ?assertError(badarg, moment:add_date(Date, ok_duration({second, 86401}))),
    ?assertEqual(ok_date(2024, 2, 29), moment:add_date(ok_date(2024, 2, 28), ok_duration({day, 1}))),
    ?assertEqual(ok_date(2023, 3, 1), moment:add_date(ok_date(2023, 2, 28), ok_duration({day, 1}))).

datetime_add_test() ->
    DT = ok_datetime(ok_date(2024, 1, 23), ok_time(12, 45, 0)),
    ?assertEqual(
        ok_datetime(ok_date(2024, 1, 23), ok_time(15, 45, 0)),
        moment:add_datetime(DT, ok_duration({hour, 3}))
    ),
    ?assertEqual(
        ok_datetime(ok_date(2024, 1, 24), ok_time(2, 45, 0)),
        moment:add_datetime(DT, ok_duration({hour, 14}))
    ),
    Midnight = ok_datetime(ok_date(2024, 1, 23), ok_time(0, 0, 0, 0)),
    ?assertEqual(
        ok_datetime(ok_date(2024, 1, 22), ok_time(23, 59, 59, 999999)),
        moment:subtract_datetime(Midnight, ok_duration({microsecond, 1}))
    ).

diff_time_test() ->
    Open = ok_time(9, 0, 0),
    Close = ok_time(17, 0, 0),
    Eight = ok_duration({hour, 8}),
    ?assertEqual(Eight, moment:diff_time(Close, Open)),
    {duration, Neg} = moment:diff_time(Open, Close),
    ?assert(Neg < 0),
    ?assertError(badarg, moment:add_datetime(Open, Eight)).

duration_normalize_test() ->
    A = ok_duration({hour, 1}),
    B = ok_duration({minute, 60}),
    ?assertEqual(eq, moment:compare(A, B)),
    ?assertEqual(<<"PT1H">>, moment:format(A)),
    ?assertEqual(<<"PT1H">>, moment:format(B)),
    Mixed = ok_duration([{hour, -1}, {minute, 30}]),
    ?assertEqual(<<"-PT30M">>, moment:format(Mixed)),
    ?assertEqual(<<"P7D">>, moment:format(ok_duration({week, 1}))),
    ?assertEqual(<<"PT0S">>, moment:format(ok_duration({second, 0}))).

offset_and_instant_projection_test() ->
    DT = ok_datetime(ok_date(2024, 1, 23), ok_time(12, 45, 0)),
    InstUTC = moment:to_instant(DT, utc),
    ?assertEqual(DT, moment:from_instant(InstUTC, utc)),
    InstPlus1 = moment:to_instant(DT, {offset, 3600}),
    ?assertEqual(lt, moment:compare(InstPlus1, InstUTC)),
    ?assertError(badarg, moment:to_instant(DT, {offset, 90})),
    ?assertError(badarg, moment:to_instant(DT, {offset, 25 * 3600})),
    ?assertEqual(
        ok_datetime(ok_date(1969, 12, 31), ok_time(23, 59, 59, 999999)),
        moment:from_instant({instant, -1}, utc)
    ),
    ?assertEqual({instant, -1}, moment:to_instant(
        ok_datetime(ok_date(1969, 12, 31), ok_time(23, 59, 59, 999999)), utc)),
    MinUs = -62167219200000000,
    ?assertEqual(
        ok_datetime(ok_date(0, 1, 1), ok_time(0, 0, 0, 0)),
        moment:from_instant({instant, MinUs}, utc)
    ),
    ?assertError(out_of_range, moment:from_instant({instant, MinUs - 1}, utc)).

clock_test() ->
    Inst = moment:instant(),
    ?assert(moment:is_instant(Inst)),
    ?assert(moment:is_instant(moment:now())),
    ?assert(moment:is_datetime(moment:utc_datetime())).

iso_civil_parse_format_test() ->
    ?assertEqual({error, invalid_date}, moment:parse_date(<<"2023-02-29">>)),
    ?assertEqual({error, invalid_format}, moment:parse_date(<<"nope">>)),
    ?assertEqual({error, invalid_format}, moment:parse_date(<<"10000-01-01">>)),
    ?assertEqual({error, invalid_time}, moment:parse_time(<<"12:45:66">>)),
    ?assertEqual({error, invalid_time}, moment:parse_time(<<"24:00:00">>)),
    ?assertEqual({error, invalid_time}, moment:parse_time(<<"23:59:60">>)),
    {ok, Half} = moment:parse_time(<<"12:45:00.5">>),
    ?assertEqual(500000, moment:time_microsecond(Half)),
    {ok, Quarter} = moment:parse_time(<<"12:45:00.25">>),
    ?assertEqual(250000, moment:time_microsecond(Quarter)),
    {ok, OneUs} = moment:parse_time(<<"12:45:00.000001">>),
    ?assertEqual(1, moment:time_microsecond(OneUs)),
    {ok, Trunc} = moment:parse_time(<<"12:45:00.1234565">>),
    ?assertEqual(123456, moment:time_microsecond(Trunc)),
    Time250 = ok_time(12, 45, 0, 250000),
    ?assertEqual(<<"12:45:00.25">>, moment:format(Time250)),
    {ok, RoundTrip} = moment:parse_time(moment:format(Time250)),
    ?assertEqual(Time250, RoundTrip),
    Date = ok_date(2024, 1, 23),
    ?assertEqual(<<"2024-01-23">>, moment:format(Date)),
    ?assertEqual({ok, Date}, moment:parse_date(<<"2024-01-23">>)),
    DT = ok_datetime(Date, ok_time(12, 45, 0)),
    ?assertEqual(<<"2024-01-23T12:45:00">>, moment:format(DT)),
    ?assertEqual({ok, DT}, moment:parse_datetime(<<"2024-01-23T12:45:00">>)),
    ?assertEqual({error, invalid_format}, moment:parse_datetime(<<"2018-02-01T16:17:58Z">>)).

rfc3339_test() ->
    {ok, Inst} = moment:parse_rfc3339(<<"2018-02-01T16:17:58+01:00">>),
    ?assertEqual(<<"2018-02-01T15:17:58Z">>, moment:format(Inst)),
    ?assertEqual(<<"2018-02-01T16:17:58+01:00">>, moment:format(Inst, {offset, 3600})),
    ?assertEqual(<<"-01:00">>, binary:part(moment:format(Inst, {offset, -3600}),
        {byte_size(moment:format(Inst, {offset, -3600})) - 6, 6})),
    ?assertEqual(<<"Z">>, binary:part(moment:format(Inst, {offset, 0}),
        {byte_size(moment:format(Inst, {offset, 0})) - 1, 1})),
    {ok, InstZ} = moment:parse_rfc3339(<<"2018-02-01t15:17:58z">>),
    ?assertEqual(InstZ, element(2, moment:parse_rfc3339(<<"2018-02-01T15:17:58Z">>))),
    ?assertEqual({error, invalid_time}, moment:parse_rfc3339(<<"2016-12-31T23:59:60Z">>)),
    ?assertEqual({error, invalid_format}, moment:parse_rfc3339(<<"10000-01-01T00:00:00Z">>)),
    ?assertError(badarg, moment:format(Inst, {offset, 90})),
    ?assertError(badarg, moment:format(Inst, {offset, 25 * 3600})),
    {ok, Edge} = moment:parse_rfc3339(<<"0000-01-01T00:00:00+14:00">>),
    ?assertError(out_of_range, moment:format(Edge)),
    Formatted = moment:format(Edge, {offset, 14 * 3600}),
    ?assertEqual(<<"0000-01-01T00:00:00+14:00">>, Formatted).

duration_iso_test() ->
    Dur = ok_duration({hour, 3}),
    ?assertEqual(<<"PT3H">>, moment:format(Dur)),
    ?assertEqual({ok, Dur}, moment:parse_duration(<<"PT3H">>)),
    ?assertEqual({ok, Dur}, moment:duration({minute, 180})),
    ?assertEqual(<<"PT3H">>, moment:format(ok_duration({minute, 180}))),
    Day = ok_duration({hour, 24}),
    ?assertEqual(<<"P1D">>, moment:format(Day)),
    {ok, Parsed24} = moment:parse_duration(<<"PT24H">>),
    ?assertEqual(<<"P1D">>, moment:format(Parsed24)),
    ?assertEqual({ok, ok_duration({microsecond, 1500000})}, moment:parse_duration(<<"PT1.5S">>)),
    ?assertEqual({error, invalid_format}, moment:parse_duration(<<"PT1.5H">>)),
    ?assertEqual({error, invalid_duration}, moment:parse_duration(<<"P1M">>)),
    ?assertEqual({error, invalid_format}, moment:parse_duration(<<"%%%">>)),
    {ok, FromLower} = moment:parse_duration(<<"pt3h">>),
    ?assertEqual(Dur, FromLower),
    {ok, W} = moment:parse_duration(<<"P1W">>),
    ?assertEqual(<<"P7D">>, moment:format(W)),
    ?assertEqual({error, invalid_duration}, moment:duration({month, 1})),
    ?assertEqual({error, invalid_duration}, moment:duration({hours, 1})).

compare_test() ->
    ?assertEqual(lt, moment:compare(ok_date(2024, 1, 1), ok_date(2024, 1, 2))),
    ?assertEqual(eq, moment:compare(ok_date(2024, 1, 1), ok_date(2024, 1, 1))),
    ?assertError(badarg, moment:compare(ok_date(2024, 1, 1), ok_time(0, 0, 0))).
