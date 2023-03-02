<p align="center">
  <a href="https://github.com/ualbertalib/pushmi_pullyu/">
    <img src="docs/images/pushmi-pullyu.png" alt="PushmiPullyu logo">
  </a>
</p>

[![Gem Version](https://badge.fury.io/rb/pushmi_pullyu.svg)](https://rubygems.org/gems/pushmi_pullyu)
[![Github Build Status](https://github.com/ualbertalib/pushmi_pullyu/workflows/CI/badge.svg)](https://github.com/ualbertalib/pushmi_pullyu/actions)

PushmiPullyu is a Ruby application, running behind the firewall that protects our Swift environment.

Its primary job is to manage the flow of content from Jupiter into Swift for preservation.

![System Infrastructure Diagram](docs/images/system-infrastructure-diagram.png)

## Workflow

1.  Any save (create or update) on a Item/Thesis in ERA/Jupiter will trigger an after save callback that will push the item's unique identifier (UUID) into a Queue.
2. The queue (Redis) is setup to be a unique set (which only allows one item's UUID to be included in the queue at a single time), and ordered by priority from First In, First out (FIFO).
3. PushmiPullyu will then monitor the queue. After a certain wait period has passed since an element has been on the queue, PushmiPullyu will then retrieve the elements off the queue and begin to process the preservation event.
4. All the Item/Thesis information and data required for preservation are retrieved from Jupiter using multiple REST calls to Jupiter's AIP API.
5. An Archival Information Package (AIP) is created from the item's information. It is then bagged and tarred.
6. The AIP tar is then uploaded to Swift via a REST call.
7. On a successful Swift upload, a entry is added for this preservation event to the preservation event logs.


## Requirements

PushmiPullyu supports Ruby 2.7

## Installation

PushmiPullyu is hosted on rubygems.org. Therefore it can be installed via:

```bash
  gem install pushmi_pullyu
```

## Usage

Foreground mode:
```bash
  pushmi_pullyu
```

Run as a daemon:
```bash
  pushmi_pullyu start
```

PushmiPullyu is quite flexible in that many options can be specified at the command line.
Use `pushmi_pullyu --help` to see all the command line options available.

Example:

```
Usage: pushmi_pullyu [options] [start|stop|restart|run]

Specific options:
  -a, --minimum-age AGE            Minimum amount of time an item must spend in the queue, in seconds.
  -d, --debug                      Enable debug logging
  -r, --rollbar-token TOKEN        Enable error reporting to Rollbar
  -C, --config PATH                Path for YAML config file
  -L, --logdir PATH                Path for directory to store log files
  -D, --piddir PATH                Path for directory to store pid files
  -W, --workdir PATH               Path for directory where AIP creation work takes place in
  -N, --process_name NAME          Name of the application process
  -m, --monitor                    Start monitor process for a deamon
  -q, --queue NAME                 Name of the queue to read from    
  -i, --ingestion_prefix PREFIX    Prefix for keys used in counting the number of failed ingestion attempts
  -x, --ingestion_attempts NUMBER  Max number of attempts to try ingesting an entity
  -f, --first_failed_wait NUMBER   Time in seconds to wait after first failed entity deposit. This time will double every failed attempt

Common options:
  -v, --version                    Show version
  -h, --help                       Show this message
```

## Configuration file

You can also provide a configuration file which PushmiPullyu will use with the -C (or --config) flag:

```bash
  pushmi_pullyu start -C /path/to/config.yml
```

By default, if no configuration file is specified, PushmiPullyu will look for a configuration file at config/pushmi_pullyu.yml.

Take the following [sample configuration](https://github.com/ualbertalib/pushmi_pullyu/blob/master/examples/pushmi_pullyu.yml) as inspiration or check out the [DEFAULTS hash](https://github.com/ualbertalib/pushmi_pullyu/blob/master/lib/pushmi_pullyu.rb) in the main module to see all available options.

Options passed on the command line will also override options specified in the config file.

## Signals

PushmiPullyu responds to these signals:

* `INT`: Equivalent of sending Ctrl-C to PushmiPullyu. Will attempt to finish then exit.
* `TERM`: Similar to `INT`. PushmiPullyu will attempt to finish then exit.
* `HUP`: Reopens log files as defined in logfile configuration options.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You'll need to set these two env vars otherwise you'll likely run into an error (Errno::ECONNRESET: Connection reset by peer):

```bash
export JUPITER_API_KEY=3eeb395e-63b7-11ea-bc55-0242ac130003
export JUPITER_USER=ditech@ualberta.ca
```

## Testing

Pre-requisites:

Will need jupiter running locally and Openstack Swift running on port 8080.
- [Instructions for jupiter](https://github.com/ualbertalib/jupiter#docker)
- Use `docker-compose up -d` to start Swift (additional instructions in docker-compose.yml)

To run the test suite:

```bash
  bundle install
  bundle exec rake
```

This will run both rspec and rubocop together.

To run rspec by itself:

```bash
  bundle exec rspec
```
To run rubocop by itself:

```bash
  bundle exec rubocop
```
## Releasing a new gem version

To release a new version, bump the version file found here: `lib/pushmi_pullyu/version.rb`

Try to bump versions using [semantic versioning](http://semver.org/).

Commit this change into master branch via a PR.

Once committed, you can do a release by running the following rake command:

`rake release[remote]`

This will cut a tag version, builds the gem, and pushes the gem up to Rubygems

Note: You may need permission to push a gem up to Rubygems!
You will first need to create an account on rubygems.org.
Once you have an account, bug @pgwillia (Tricia Jenkins), @lagoan (Omar Rodriguez-Arenas), or @henryzhang87 (Henry Zhang) to [add you as an owner](http://guides.rubygems.org/command-reference/#gem-owner) to pushmi_pullyu Rubygem. Once you are an owner you should be able to push new versions of pushmi_pullyu up to Rubygems

## Deployment

TODO: Fill me out

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

