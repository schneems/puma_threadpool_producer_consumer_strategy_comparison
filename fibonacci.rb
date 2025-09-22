#!/usr/bin/env ruby

require 'bigdecimal'

def fibonacci(n)
  return n if n <= 1
  fibonacci(n - 1) + fibonacci(n - 2)
end

def time_fibonacci(n)
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)
  fibonacci(n)
  end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)

  BigDecimal(end_time.to_s) - BigDecimal(start_time.to_s)
end

# Given a number between 0.0 and 1.0 calculate how long to sleep
# so that a workload matches that percentage of IO time.
def calculate_sleep_time(io_percentage:, fibonacci_number:)
  cpu_time = time_fibonacci(fibonacci_number)

  return Float::INFINITY if io_percentage >= 1.0
  return BigDecimal("0") if io_percentage <= 0.0

  (io_percentage / (1.0 - io_percentage)) * cpu_time
end
