module Tabs
  module Metrics
    class Task
      include Tabs::Storage
      include Tabs::Helpers

      class UnstartedTaskMetricError < Exception; end

      Stats = Struct.new(
        :started_within_period,
        :completed_within_period,
        :started_and_completed_within_period,
        :completion_rate,
        :average_completion_time,
        :average_completion_time_in_seconds
      )

      attr_reader :key

      def initialize(key)
        @key = key
      end

      def start(token, timestamp=Time.now)
        Token.new(token, key).start(timestamp)
        true
      end

      def complete(token, timestamp=Time.now)
        Token.new(token, key).complete(timestamp)
        true
      end

      def stats(period, resolution)
        range = timestamp_range(period, resolution)
        started_tokens = tokens_for_period(range, resolution, "started")
        completed_tokens = tokens_for_period(range, resolution, "completed")
        matching_tokens = started_tokens.select { |token| completed_tokens.include? token }
        completion_rate = (matching_tokens.size.to_f / range.size).round(Config.decimal_precision)
        elapsed_times = matching_tokens.map { |t| t.time_elapsed(resolution) }
        elapsed_times_in_seconds = matching_tokens.map { |t| t.time_elapsed_in_seconds }
        average_completion_time = matching_tokens.blank? ? 0.0 : (elapsed_times.sum) / matching_tokens.size
        average_completion_time_in_seconds = matching_tokens.blank? ? 0.0 : (elapsed_times_in_seconds.sum) / matching_tokens.size
        Stats.new(
          started_tokens.size,
          completed_tokens.size,
          matching_tokens.size,
          completion_rate,
          average_completion_time, 
          average_completion_time_in_seconds
        )
      end

      def drop!
        del_by_prefix("stat:task:#{key}")
      end

      def storage_key(resolution, timestamp, type)
        formatted_time = Tabs::Resolution.serialize(resolution, timestamp)
        "stat:task:#{key}:#{type}:#{resolution}:#{formatted_time}"
      end

      private

      def tokens_for_period(range, resolution, type)
        keys = keys_for_range(range, resolution, type)
        smembers_all(*keys).compact.map(&:to_a).flatten.map { |t| Token.new(t, key) }
      end

      def keys_for_range(range, resolution, type)
        range.map { |timestamp| storage_key(resolution, timestamp, type) }
      end

    end
  end
end
