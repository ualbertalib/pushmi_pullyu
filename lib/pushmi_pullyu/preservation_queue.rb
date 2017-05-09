require 'redis'
require 'connection_pool'

# Quick and dirty take on sorted sets

# 1) Create a sorted set in Redis (https://redis.io/topics/data-types). Call it preservation_queue
#
# 2) In GenericFile add an after_save that:
#    - determines a monotonically increasing "score". Obvious scores would be either the time in seconds/milliseconds
#      or using something like redis INCR to create an atomic, increasing counter. It doesn't matter if 2 different
#      noids ever have the same score, it only that scores generally increase over time.
#    - zadd preservation_queue score "noid" adds the noid and gives it the score from above.
#
# 3) Pushmi-pullyu pops elements out of the sorted set, lowest score to highest.
#
# A sorted set will only ever contain a noid once, with whatever score it was last given. Because preservation_queue
# is sorted lowest score to highest, and because scores increase over time, a cascade of jobs/updates will cause a noid
# to keep "moving back" in the queue until it becomes the least recently updated noid in the queue, at which point it
# will be popped and preserved. Any further updates will trigger a new AIP build.
class PushmiPullyu::PreservationQueue

  class ConnectionError < StandardError; end

  def initialize(connection: {}, pool_opts: { size: 1, timeout: 5 }, poll_interval: 10, age_at_least: 0,
                 queue_name: 'dev:pmpy_queue')
    # we use a connection pool even though we're not (currently) threading
    # as it transparently provides for repairing connections if they are closed after long periods of inactivity
    @redis = ConnectionPool.new(pool_opts) do
      connection.reverse_merge!(host: 'localhost', port: 6379)
      Redis.new(connection)
    end

    raise ConnectionError unless connected?

    @poll_interval = poll_interval
    @age_at_least = age_at_least
    @queue_name = queue_name
  rescue StandardError => e
    # TODO: logging
    abort("Could not get a valid connection to Redis. #{e}")
  end

  def next_item
    raise ConnectionError unless connected?

    @redis.with do |conn|
      conn.watch(@queue_name) do |rd| # transactional mutation of the set is dependent on the set key
        element, score = rd.zrange(@queue_name, 0, 0, with_scores: true).first

        if element && ((Time.now.to_f - @age_at_least) >= score)
          rd.multi do |tx|
            tx.zrem(@queue_name, element) # remove the top element transactionally
          end
          return element
        else
          rd.unwatch # cancel the transaction since there was nothing in the queue
          return nil
        end
      end
    end
  end

  def wait_next_item
    # loop do
    element = next_item
    return element if element.present?
    sleep @poll_interval
    # end
  end

  protected

  def connected?
    @redis.with do |conn|
      conn.ping == 'PONG'
    end
  end

end
