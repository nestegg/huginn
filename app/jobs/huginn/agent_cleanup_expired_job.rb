module Huginn
  class AgentCleanupExpiredJob < ActiveJob::Base
    queue_as :default

    def perform
      Huginn::Event.cleanup_expired!
    end
  end
end
