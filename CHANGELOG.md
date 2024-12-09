# Changelog
All notable changes to PushmiPullyu project will be documented in this file. 

PushmiPullyu is a Ruby application, whose primary job is to manage the flow of content from [Jupiter](https://github.com/ualbertalib/jupiter/) into Swift for preservation.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and releases in PushmiPullyu adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.6] 2024-12-09

### Fixed
- pin version of securerandom that work with Ruby 2.7

## [2.1.5] 2024-11-27

### Fixed
 - Permit versions of activesupport that work with Ruby 2.7 by @pgwillia in https://github.com/ualbertalib/pushmi_pullyu/pull/492

### Chores
 - Bump rexml from 3.3.8 to 3.3.9 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/489
 - Bump activesupport from 7.1.4 to 7.1.4.2 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/487
 - Bump danger from 9.5.0 to 9.5.1 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/486

## [2.1.4]

### Added
 - Bring in and enforce inclusive language cops [PR#469](https://github.com/ualbertalib/pushmi_pullyu/pull/469)

### Fixed
 - Use `File.open` with a block for simple exception handling and ensuring files are closed [#475](https://github.com/ualbertalib/pushmi_pullyu/issues/475)
 - Fix problem with authentication token expiration by @lagoan in https://github.com/ualbertalib/pushmi_pullyu/pull/457
 
### Changed 
 - Bump bundler from 2.3.12 to 2.4.9 [PR#483](https://github.com/ualbertalib/pushmi_pullyu/pull/483)

### Chores
 - Use add_dependency instead of add_runtime_dependency. [PR#473](https://github.com/ualbertalib/pushmi_pullyu/pull/473)
 - Bump rexml from 3.2.8 to 3.3.2 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/462
 - Bump timecop from 0.9.8 to 0.9.10 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/450
 - Bump redis from 5.0.8 to 5.3.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/468
 - Update CI for branch name changes by @pgwillia in https://github.com/ualbertalib/pushmi_pullyu/pull/480
 - Bump danger from 9.3.2 to 9.5.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/466
 - Bump bagit from 0.4.6 to 0.6.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/482
 - Update minitar requirement from ~> 0.7 to >= 0.7, < 2.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/481
 - Bump rubocop-rspec from 2.24.1 to 3.1.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/478
 - Bump rdf from 3.2.11 to 3.2.12 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/479
 - Bump webmock from 3.19.1 to 3.24.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/477
 - Bump rubocop from 1.64.0 to 1.66.1 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/473
 - Bump rollbar from 3.4.1 to 3.6.0 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/472
 - Bump activesupport from 7.1.1 to 7.1.4 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/470
 - Bump rake from 13.0.6 to 13.2.1 by @dependabot in https://github.com/ualbertalib/pushmi_pullyu/pull/426

## [2.1.3]
 - Refresh authentication token after it expires [#311](https://github.com/ualbertalib/pushmi_pullyu/issues/311)

## [2.1.2]
 - Simplify get entity code [#280](https://github.com/ualbertalib/pushmi_pullyu/issues/280)

## [2.1.1]
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
