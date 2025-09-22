#!/usr/bin/env ruby

require_relative 'queue_strategy'
require_relative 'mutex_cv_strategy'

begin
  require 'ruby-statistics'
rescue LoadError
  puts "Warning: ruby-statistics gem not found. Statistical analysis will use basic calculations."
end

class ThreadPoolBenchmark
  def initialize(thread_count: 3, work_count: 1000, fibonacci_number: 20, io_percentage: 0.5, runs: 3, producer_sleep_percent: 0.1)
    @thread_count = thread_count
    @work_count = work_count
    @fibonacci_number = fibonacci_number
    @io_percentage = io_percentage
    @runs = runs

    # Calculate sleep times once for consistency across all strategies
    @sleep_time = calculate_sleep_time(io_percentage: @io_percentage, fibonacci_number: @fibonacci_number)
    @producer_sleep_time = producer_sleep_percent.to_f * @sleep_time
  end

  def run_benchmark
    puts "Thread Pool Performance Comparison"
    puts "=" * 50
    puts "Configuration:"
    puts "  Thread count: #{@thread_count}"
    puts "  Work count: #{@work_count}"
    puts "  Fibonacci number: #{@fibonacci_number}"
    puts "  IO percentage: #{(@io_percentage * 100).round(1)}%"
    puts "  Benchmark runs: #{@runs}"
    puts "  Calculated sleep time: #{@sleep_time.round(6)}s (consistent across all strategies)"
    puts "  Producer sleep time: #{@producer_sleep_time.round(6)}s"
    puts

    queue_times, mutex_cv_times = benchmark_strategies_interleaved()

    compare_results(queue_times, mutex_cv_times)
    statistical_analysis(queue_times, mutex_cv_times)
  end

  private

  def benchmark_strategies_interleaved
    puts "Running interleaved benchmark (alternating strategies)..."
    queue_times = []
    mutex_cv_times = []

    strategies = [
      ["Queue Strategy", QueueStrategy],
      ["Mutex/CV Strategy", MutexCvStrategy]
    ]

    @runs.times do |run|
      # Randomize the order for each pair to avoid systematic bias
      current_strategies = strategies.shuffle

      current_strategies.each do |name, strategy_class|
        print "  Run #{run + 1}/#{@runs} - #{name}... "

        strategy = strategy_class.new(
          thread_count: @thread_count,
          work_count: @work_count,
          fibonacci_number: @fibonacci_number,
          sleep_time: @sleep_time,
          producer_sleep_time: @producer_sleep_time
        )

        elapsed_time = strategy.run

        if name == "Queue Strategy"
          queue_times << elapsed_time
        else
          mutex_cv_times << elapsed_time
        end

        puts "#{elapsed_time.round(4)}s"
      end

      # Small pause between pairs to let system settle
      sleep(0.1) if run < @runs - 1
    end

    puts
    puts "Interleaved benchmark completed."
    puts "Queue Strategy times: #{queue_times.map { |t| t.round(4) }}"
    puts "Mutex/CV Strategy times: #{mutex_cv_times.map { |t| t.round(4) }}"
    puts

    [queue_times, mutex_cv_times]
  end

  def benchmark_strategy(name, strategy_class)
    puts "Running #{name}..."
    times = []

    @runs.times do |run|
      print "  Run #{run + 1}/#{@runs}... "

      strategy = strategy_class.new(
        thread_count: @thread_count,
        work_count: @work_count,
        fibonacci_number: @fibonacci_number,
        sleep_time: @sleep_time,
        producer_sleep_time: @producer_sleep_time
      )

      elapsed_time = strategy.run
      times << elapsed_time

      puts "#{elapsed_time.round(4)}s"
    end

    puts
    times
  end

  def compare_results(queue_times, mutex_cv_times)
    queue_avg = queue_times.sum / queue_times.length
    mutex_cv_avg = mutex_cv_times.sum / mutex_cv_times.length

    puts "Results Summary:"
    puts "-" * 30
    puts "Queue Strategy:"
    puts "  Average time: #{queue_avg.round(4)}s"
    puts "  Min time: #{queue_times.min.round(4)}s"
    puts "  Max time: #{queue_times.max.round(4)}s"
    puts "  Times: #{queue_times.map { |t| t.round(4) }}"
    puts

    puts "Mutex/CV Strategy:"
    puts "  Average time: #{mutex_cv_avg.round(4)}s"
    puts "  Min time: #{mutex_cv_times.min.round(4)}s"
    puts "  Max time: #{mutex_cv_times.max.round(4)}s"
    puts "  Times: #{mutex_cv_times.map { |t| t.round(4) }}"
    puts

    if queue_avg < mutex_cv_avg
      ratio = mutex_cv_avg / queue_avg
      puts "Performance Comparison:"
      puts "Queue Strategy is #{ratio.round(2)}x faster than Mutex/CV Strategy"
      puts "(Queue: #{queue_avg.round(4)}s vs Mutex/CV: #{mutex_cv_avg.round(4)}s)"
    elsif mutex_cv_avg < queue_avg
      ratio = queue_avg / mutex_cv_avg
      puts "Performance Comparison:"
      puts "Mutex/CV Strategy is #{ratio.round(2)}x faster than Queue Strategy"
      puts "(Mutex/CV: #{mutex_cv_avg.round(4)}s vs Queue: #{queue_avg.round(4)}s)"
    else
      puts "Performance Comparison:"
      puts "Both strategies performed equally (1.0x)"
    end

    puts
    puts "Detailed Analysis:"
    difference_percent = ((queue_avg - mutex_cv_avg).abs / [queue_avg, mutex_cv_avg].min * 100).round(2)
    puts "Performance difference: #{difference_percent}%"
  end

  def statistical_analysis(queue_times, mutex_cv_times)
    puts
    puts "Statistical Analysis:"
    puts "=" * 30

    # Basic descriptive statistics
    puts "Queue Strategy Statistics:"
    queue_mean = mean(queue_times)
    queue_median = median(queue_times)
    queue_std = standard_deviation(queue_times)
    queue_var = variance(queue_times)

    puts "  Mean: #{queue_mean.round(6)}s"
    puts "  Median: #{queue_median.round(6)}s"
    puts "  Standard Deviation: #{queue_std.round(6)}s"
    puts "  Variance: #{queue_var.round(8)}s²"
    puts "  Coefficient of Variation: #{(queue_std / queue_mean * 100).round(2)}%"
    puts

    puts "Mutex/CV Strategy Statistics:"
    mutex_cv_mean = mean(mutex_cv_times)
    mutex_cv_median = median(mutex_cv_times)
    mutex_cv_std = standard_deviation(mutex_cv_times)
    mutex_cv_var = variance(mutex_cv_times)

    puts "  Mean: #{mutex_cv_mean.round(6)}s"
    puts "  Median: #{mutex_cv_median.round(6)}s"
    puts "  Standard Deviation: #{mutex_cv_std.round(6)}s"
    puts "  Variance: #{mutex_cv_var.round(8)}s²"
    puts "  Coefficient of Variation: #{(mutex_cv_std / mutex_cv_mean * 100).round(2)}%"
    puts

    # Kolmogorov-Smirnov test
    puts "Kolmogorov-Smirnov Two-Sample Test:"
    puts "-" * 40

    begin
      # Perform the KS test to compare distributions
      ks_statistic = kolmogorov_smirnov_statistic(queue_times, mutex_cv_times)
      critical_value = kolmogorov_smirnov_critical_value(queue_times.length, mutex_cv_times.length)

      puts "KS Statistic: #{ks_statistic.round(6)}"
      puts "Critical Value (α=0.05): #{critical_value.round(6)}"

      if ks_statistic > critical_value
        puts "Result: ✅✅✅ REJECT null hypothesis (p < 0.05)"
        puts "Interpretation: The two distributions are significantly different."
        puts "The threading strategies have statistically different performance characteristics."
      else
        puts "Result: ❌❌❌ FAIL TO REJECT null hypothesis (p >= 0.05)"
        puts "Interpretation: No significant difference between distributions."
        puts "The threading strategies have statistically similar performance characteristics."
      end

      # Additional interpretation
      puts
      puts "Distribution Comparison:"
      if queue_std < mutex_cv_std
        puts "Queue Strategy shows more consistent performance (lower variance)."
      elsif mutex_cv_std < queue_std
        puts "Mutex/CV Strategy shows more consistent performance (lower variance)."
      else
        puts "Both strategies show similar consistency in performance."
      end

    rescue => e
      puts "Error performing KS test: #{e.message}"
      puts "This may be due to insufficient sample size or identical distributions."
    end
  end

  # Calculate Kolmogorov-Smirnov statistic for two samples
  def kolmogorov_smirnov_statistic(sample1, sample2)
    # Sort both samples
    sorted1 = sample1.sort
    sorted2 = sample2.sort

    # Get all unique values from both samples
    all_values = (sorted1 + sorted2).uniq.sort

    max_diff = 0.0
    n1 = sample1.length.to_f
    n2 = sample2.length.to_f

    all_values.each do |value|
      # Calculate empirical distribution functions
      cdf1 = sorted1.count { |x| x <= value } / n1
      cdf2 = sorted2.count { |x| x <= value } / n2

      # Track maximum difference
      diff = (cdf1 - cdf2).abs
      max_diff = [max_diff, diff].max
    end

    max_diff
  end

  # Calculate critical value for KS test (approximate)
  def kolmogorov_smirnov_critical_value(n1, n2, alpha = 0.05)
    # For α = 0.05, critical value approximation
    c_alpha = 1.36  # Critical value for α = 0.05

    sqrt_term = Math.sqrt((n1 + n2).to_f / (n1 * n2))
    c_alpha * sqrt_term
  end

  # Basic statistical functions
  def mean(data)
    data.sum.to_f / data.length
  end

  def median(data)
    sorted = data.sort
    n = sorted.length
    if n.odd?
      sorted[n / 2]
    else
      (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    end
  end

  def variance(data)
    m = mean(data)
    data.map { |x| (x - m) ** 2 }.sum / (data.length - 1).to_f
  end

  def standard_deviation(data)
    Math.sqrt(variance(data))
  end
end

if __FILE__ == $0
  puts "Statistical Performance Analysis"
  puts "=" * 40

  # Run with more iterations for better statistical power
  benchmark = ThreadPoolBenchmark.new(
    thread_count: 3,
    fibonacci_number: 5, # Calculate the fibonacci number of this input
    work_count: 10_000, # Do it this many times
    io_percentage: 0.01, # 0.01 is 1% of time spent doing IO
    # Take care, if you make this too large then you're starving the consumers and you're measuring time to enqueue work instead of complete it.
    producer_sleep_percent: 0.0,
    runs: 70  # When perf is close, we need more runs to prove statistical significance
  )
  benchmark.run_benchmark
end
