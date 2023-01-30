require 'spec_helper'
require 'timecop'

RSpec.describe PushmiPullyu::PreservationQueue do
  describe 'a queue with 3 items in it' do
    let(:queue) { PushmiPullyu::PreservationQueue.new(poll_interval: 0, queue_name: 'test:pmpy_queue') }
    let!(:redis) { Redis.new }

    before do
      PushmiPullyu.server_running = true
      redis.zadd 'test:pmpy_queue', 1, '{"uuid":"9e3be94f-a5de-4589-96ca-b18efba280c1","type":"items"}'
      redis.zadd 'test:pmpy_queue', 3, '{"uuid":"9e3be94f-a5de-4589-96ca-b18efba280c3","type":"items"}'
      redis.zadd 'test:pmpy_queue', 4, '{"uuid":"9e3be94f-a5de-4589-96ca-b18efba280c2","type":"items"}'
      redis.zadd 'test:pmpy_queue', 10, '{"uuid":"9e3be94f-a5de-4589-96ca-b18efba280c1","type":"items"}'
    end

    after do
      redis.del 'test:pmpy_queue'
    end

    it 'retrieves 3 items in priority order' do
      next_item = queue.wait_next_item

      expect(next_item[:uuid]).to eq '9e3be94f-a5de-4589-96ca-b18efba280c3'
      next_item = queue.wait_next_item
      expect(next_item[:uuid]).to eq '9e3be94f-a5de-4589-96ca-b18efba280c2'
      next_item = queue.wait_next_item
      expect(next_item[:uuid]).to eq '9e3be94f-a5de-4589-96ca-b18efba280c1'
    end
  end

  describe 'a queue with items under a minimum age' do
    let(:queue) do
      PushmiPullyu::PreservationQueue.new(poll_interval: 0, queue_name: 'test:pmpy_queue', age_at_least: 15.minutes)
    end
    let!(:redis) { Redis.new }

    before do
      redis.zadd 'test:pmpy_queue', Time.now.to_f, '{"uuid":"9e3be94f-a5de-4589-96ca-b18efba280c1","type":"items"}'
    end

    after do
      Timecop.return
      redis.del 'test:pmpy_queue'
    end

    it 'does not retrieve too young items' do
      now = Time.now
      Timecop.freeze(now)

      expect(queue.next_item).to be_nil

      Timecop.travel(now + 14.minutes)
      expect(queue.next_item).to be_nil

      Timecop.travel(now + 15.minutes)
      expect(queue.next_item[:uuid]).to eq '9e3be94f-a5de-4589-96ca-b18efba280c1'
    end
  end
end
