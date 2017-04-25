# PushmiPullyu

PushmiPullyu will be a Ruby application, running behind the firewall that protects our Swift environment.

It's primary job will be to manage the flow of content from Fedora into Swift for preservation.

![image](https://cloud.githubusercontent.com/assets/1930474/25407462/99193a5c-29c7-11e7-8aa0-0a43554e6eb1.png)

## Workflow

1.  Any save (Creation/Update) on a GenericFile in ERA will trigger an after save callback which will push the GF information (most likely it's primary ID) into a Queue
2. The queue (will most likely be using Redis) needs to be unique, aka a set (which only allows one GF to be included in the queue at a single time), and ordered by priority from First In, First out (FIFO).
3. PushmiPullyu app will then monitor this queue. After a certain window of wait period has passed since an element has been on the queue, PushmiPullyu will then retrieve the elements off the queue and begin to process the preservation event
4. The GenericFile information and data required for preservation are retrieved from Fedora using multiple REST calls
5. An AIP is created with the GenericFile's information and is bagged.
6. The AIP is uploaded and pushed to Swift via a REST call
7. On a successful Swift upload, a log entry is added for this preservation event

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pushmi_pullyu'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pushmi_pullyu

## Usage

1. `gem install pushmi_pullyu`
2. `pushmi_pullyu`

Use `pushmi_pullyu --help` to see the command line options.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

