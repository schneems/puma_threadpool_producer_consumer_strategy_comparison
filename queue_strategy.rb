#!/usr/bin/env ruby

require_relative 'fibonacci'
require 'thread'

class QueueStrategy
  POISON_PILL = :shutdown

  def initialize(thread_count: 3, work_count: 1000, fibonacci_number: 20, sleep_time:, producer_sleep_time:)
    @thread_count = thread_count
    @work_count = work_count
    @fibonacci_number = fibonacci_number

    @queue = Queue.new
    @threads = []

    @sleep_time = sleep_time
    @producer_sleep_time = producer_sleep_time
    @ready_mutex = Mutex.new
    @ready_count = 0
  end

  def run
    start_threads
    while @ready_count < @thread_count
      sleep(0.0001)
    end

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)

    produce_work
    shutdown_threads
    wait_for_completion

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)

    end_time - start_time
  end

  private

  def start_threads
    @thread_count.times do |i|
      @threads << Thread.new do
        @ready_mutex.synchronize do
          @ready_count += 1
        end

        consumer_loop
      end
    end
  end

  def consumer_loop
    loop do
      work = @queue.pop

      if work == POISON_PILL
        Thread.exit
      end

      fibonacci(work)
      sleep(@sleep_time)
    end
  end

  def produce_work
    @work_count.times do
      @queue.push(@fibonacci_number)
      sleep(@producer_sleep_time)
    end
  end

  def shutdown_threads
    @thread_count.times do
      @queue.push(POISON_PILL)
    end
  end

  def wait_for_completion
    @threads.each(&:join)
  end
end
