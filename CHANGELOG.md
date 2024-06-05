# Changelog
All notable changes to PushmiPullyu project will be documented in this file. 

PushmiPullyu is a Ruby application, whose primary job is to manage the flow of content from [Jupiter](https://github.com/ualbertalib/jupiter/) into Swift for preservation.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and releases in PushmiPullyu adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
 - Increase clarity of log files [#433](https://github.com/ualbertalib/pushmi_pullyu/issues/433)

## [2.1.0]
 - Add more logging information [#433](https://github.com/ualbertalib/pushmi_pullyu/issues/433)
 - Add V3 authentication [#349](https://github.com/ualbertalib/pushmi_pullyu/issues/349)

- Add logic to perform authentication against the V3 Auth protocol

## [2.0.7] - 2023-09-13

- Fix nil exception [#314](https://github.com/ualbertalib/pushmi_pullyu/issues/314)
- Bump rubocop from 1.28.1 to 1.54.1 [PR#348](https://github.com/ualbertalib/pushmi_pullyu/pull/348)
- Add missing logging for standard exception [#314](https://github.com/ualbertalib/pushmi_pullyu/issues/314)
## [2.0.6] - 2023-03-17

- Fix URI concatenation for jupiter's base url. [#309](https://github.com/ualbertalib/pushmi_pullyu/issues/309)

## [2.0.5] - 2023-02-17

- Add rescue block to catch exceptions while waiting for next item [#280](https://github.com/ualbertalib/pushmi_pullyu/issues/280)
- Add logic to fetch new community and collection information from jupiter and create their AIPS. [#255](https://github.com/ualbertalib/pushmi_pullyu/issues/255)
- Add delay to re-ingestion attempts to allow for problems to be fixed [#297](https://github.com/ualbertalib/pushmi_pullyu/issues/297)
- Bump git from 1.9.1 to 1.13.0

## [2.0.4] - 2022-11-22

- Fix issue with temporary work files not being deleted after a failed swift deposit [#242](https://github.com/ualbertalib/pushmi_pullyu/issues/242)
- Bump to Ruby 2.7
- Fix issue with entity information consumed even after failed deposit [#232](https://github.com/ualbertalib/pushmi_pullyu/issues/232)
- Bump rspec from 3.10.0 to 3.12.0
- Bump rollbar from 3.3.0 to 3.3.2
- Bump pry-byebug from 3.8.0 to 3.10.1
- Bump webmock from 3.14.0 to 3.18.1
- Bump rubocop-rspec from 2.6.0 to 2.11.1
- Bump timecop from 0.9.4 to 0.9.5
## [2.0.3] - 2022-04-28

- Changed Danger token in Github Actions
- remove pg dependency
- unblock CI (rubocop and coveralls)
- Log to preservation_events.json as well in an easy to use json format.

## [2.0.2] - 2021-11-22

- Fix authentication bug when using ssl 
- bump rubocop and rubocop-rspec

## [2.0.1] - 2021-02-02

- Fix dependency declaration for UUID gem

## [2.0.0] - 2020-12-14

### Removed
- Data output for original_file information

## [1.0.6] - 2018-11-29
