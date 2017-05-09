require 'spec_helper'
require 'timecop'

RSpec.describe PushmiPullyu::PreservationQueue do
  describe 'a queue with 3 items in it' do
    let(:queue) { described_class.new(poll_interval: 0, queue_name: 'test:pmpy_queue') }

    before do
      direct_redis = Redis.new
      direct_redis.del  'test:pmpy_queue'
      direct_redis.zadd 'test:pmpy_queue', 1, 'noid1'
      direct_redis.zadd 'test:pmpy_queue', 3, 'noid3'
      direct_redis.zadd 'test:pmpy_queue', 4, 'noid2'
      direct_redis.zadd 'test:pmpy_queue', 10, 'noid1'
    end

    it 'retrieves 3 items in priority order' do
      expect(queue.wait_next_item).to eq 'noid3'
      expect(queue.wait_next_item).to eq 'noid2'
      expect(queue.wait_next_item).to eq 'noid1'
    end
  end

  describe 'a queue with items under a minimum age' do
    let(:queue) do
      described_class.new(poll_interval: 0, queue_name: 'test:pmpy_queue', age_at_least: 15.minutes)
    end

    before do
      direct_redis = Redis.new
      direct_redis.del 'test:pmpy_queue'

      direct_redis.zadd 'test:pmpy_queue', Time.now.to_f, 'noid1'
    end

    after { Timecop.return }

    it 'does not retrieve too young items' do
      now = Time.now
      Timecop.freeze(now)

      expect(queue.next_item).to be nil

      Timecop.travel(now + 14.minutes)
      expect(queue.next_item).to be nil

      Timecop.travel(now + 15.minutes)
      expect(queue.next_item).to eq 'noid1'
    end
  end
end
