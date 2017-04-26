require 'redis'

# Quick and dirty take on sorted sets

# 1) Create a sorted set in Redis (https://redis.io/topics/data-types). Call it preservation_queue
#
# 2) In GenericFile add an after_save that:
#    - determines a monotonically increasing "score". Obvious scores would be either the time in seconds/milliseconds
#      or using something like redis INCR to create an atomic, increasing counter. It doesn't matter if 2 different noids
#      ever have the same score, it only that scores generally increase over time.
#    - zadd preservation_queue score "noid" adds the noid and gives it the score from above.
#
# 3) Pushmi-pullyu pops elements out of the sorted set, lowest score to highest.
#
# A sorted set will only ever contain a noid once, with whatever score it was last given. Because preservation_queue
# is sorted lowest score to highest, and because scores increase over time, a cascade of jobs/updates will cause a noid to keep
# "moving back" in the queue until it becomes the least recently updated noid in the queue, at which point it will be
# poped and preserved. Any further updates will trigger a new AIP build.

class PushmiPullyu::PreservationQueue

  def initialize(connection=nil)
    @redis ||= Redis.new()
    @redis.ping
  rescue Exception => e
    # TODO logging
    abort("Could not get a valid connection to Redis")
  end

  def wait_next_item(poll_interval=10)
    loop do
      sleep poll_interval
      element = try_get_next_element
      return element if element
    end
  end

  protected

  def try_get_next_element
    @redis.watch('pmpy_queue') do |rd| # transactional mutation of the set is dependent on the set key
      element = rd.zrange('pmpy_queue', 0, 0).first
      if element # since the scores are time past epoch, we could choose not to pop if the element isn't sufficiently old enough at this point
        rd.multi do |tx|
          tx.zrem('pmpy_queue', element) # remove the top element transactionally
        end
        return element
      else
        rd.unwatch # cancel the transaction since there was nothing in the queue
      end
    end
  end
end
