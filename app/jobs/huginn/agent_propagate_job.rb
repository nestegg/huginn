module Huginn
  class AgentPropagateJob < ActiveJob::Base
    queue_as :default

    def perform
      Huginn::Agent.receive!
    end
  end
end
