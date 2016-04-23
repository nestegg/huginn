module Huginn
  class AgentRunScheduleJob < ActiveJob::Base
    queue_as :default

    def perform(time)
      Huginn::Agent.run_schedule(time)
    end
  end
end
