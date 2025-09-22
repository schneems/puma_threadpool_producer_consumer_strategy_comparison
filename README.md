# Thread Pool Performance Comparison

This repository implements and benchmarks two different approaches to thread pool management:

1. **Mutex/Condition Variable Strategy** - The traditional approach used by Puma today
2. **Queue Strategy** - An alternative approach using Ruby's built-in Queue data structure

## Use

```
$ gem install ruby-statistics
```

Run:

```
$ ruby benchmark.rb
# ...
Performance Comparison:
Queue Strategy is 1.02x faster than Mutex/CV Strategy
(Queue: 0.126s vs Mutex/CV: 0.1289s)

Detailed Analysis:
Performance difference: 2.32%

# ...

Kolmogorov-Smirnov Two-Sample Test:
----------------------------------------
KS Statistic: 0.271429
Critical Value (α=0.05): 0.229882
Result: ✅✅✅ REJECT null hypothesis (p < 0.05)
```

Configure by modifying the values at the bottom of the file. Make sure you see `✅✅✅ REJECT null hypothesis` from the output, or you might be testing random noise instead of the perf difference of the two strategies.


## Threading Strategies

### Mutex/Condition Variable Strategy (`mutex_cv_strategy.rb`)

This strategy mirrors **Puma's current implementation**:

- **Consumer threads** use a mutex to synchronize access to a shared work queue
- Threads wait on a condition variable when no work is available
- The **producer** locks the mutex, adds work, and signals one waiting thread
- Requires manual synchronization with `Mutex` and `ConditionVariable`

### Queue Strategy (`queue_strategy.rb`)

This strategy uses Ruby's thread-safe `Queue` class:

- **Consumer threads** block on `Queue.pop()` - no manual synchronization needed
- The **producer** simply pushes work with `Queue.push()`
- Ruby's `Queue` handles all thread coordination internally
- Uses "poison pill" pattern for graceful shutdown

## Workload Simulation

### Producer Loop (Puma's Accept Loop)

The producer represents **Puma's accept loop** - the main thread that accepts incoming HTTP requests and distributes them to worker threads.

### Consumer Loop (Request Processing)

Each consumer thread represents **serving an individual HTTP request** - the actual work of processing a request and generating a response.

### Workload Parameters

#### `io_percentage` - CPU vs I/O Heavy Workloads

Controls the ratio of CPU work to I/O wait time to simulate different types of web applications:

- **`0.0` (0% I/O)**: Pure CPU-bound workload (heavy computation, JSON processing)
- **`0.5` (50% I/O)**: Balanced workload (typical web app with database queries)
- **`0.9` (90% I/O)**: I/O-heavy workload (lots of database/API calls, file operations)

#### `producer_sleep_time` - Request Arrival Patterns

Simulates different request arrival scenarios:

- **`0.0` (no sleep)**: Burst traffic - all requests arrive simultaneously
- **Low values**: Steady high-traffic scenarios
- **Higher values**: Slower, more spaced-out request arrivals

If you set this to a high value you're simulating a scenario where work is coming in much slower than the amount of time it takes to do it.


### Custom Configuration

```ruby
benchmark = ThreadPoolBenchmark.new(
  thread_count: 3,           # Number of worker threads (like Puma workers)
  work_count: 1000,          # Number of requests to process
  fibonacci_number: 20,      # CPU work complexity
  io_percentage: 0.7,        # 70% I/O, 30% CPU
  runs: 10                   # Statistical runs for averaging
)
benchmark.run_benchmark
```
