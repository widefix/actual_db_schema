# frozen_string_literal: true

module ActualDbSchema
  class RollbackStatsSubscriber
    class << self
      def enable!
        return if enabled?

        @subscription = ActiveSupport::Notifications.subscribe(ActualDbSchema::Instrumentation::ROLLBACK_EVENT) do |_name, _start, _finish, _id, payload|
          RollbackStatsRepository.record(payload)
        end
      end

      def disable!
        return unless enabled?

        ActiveSupport::Notifications.unsubscribe(@subscription)
        @subscription = nil
      end

      def enabled?
        !@subscription.nil?
      end

      def stats
        RollbackStatsRepository.stats
      end

      def total_rollbacks
        RollbackStatsRepository.total_rollbacks
      end

      def reset!
        RollbackStatsRepository.reset!
      end
    end
  end
end
