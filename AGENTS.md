# moment

- Pure Erlang library in the `core-libs` family. Released. GitHub `erlangsters/moment`. Git tags only; no Hex package.
- Typed civil-time library. The public API is `src/moment.erl`: tagged `date`, `time`, `datetime`, `instant`, and `duration`, with split arithmetic names (`add_date/2`, `add_datetime/2`, …).
- Do not treat dump constructors (`moment:moment/0`, `timedelta`, overloaded `add/2`, 0-arity civil clocks) as the API. Historical sketches live in the family `internal-docs/` folder, not in this repository.
- Not a Moment.js port and not a `qdate` clone. No IANA/tzdata, no `os_local_datetime/0`, no `from_otp_*` aliases, no `shift/2`.
