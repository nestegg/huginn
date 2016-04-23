require "rails_helper"

describe Huginn::Agents::DigestAgent do
  before do
    @checker = Huginn::Agents::DigestAgent.new(:name => "something", :options => { :expected_receive_period_in_days => "2", :message => "{{ events | map:'data' | join:';' }}" })
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#working?" do
    it "checks to see if the Agent has received any events in the last 'expected_receive_period_in_days' days" do
      event = Huginn::Event.new
      event.agent = huginn_agents(:bob_rain_notifier_agent)
      event.payload = { :data => "event" }
      event.save!

      expect(@checker).not_to be_working # no events have ever been received
      Huginn::Agents::DigestAgent.async_receive(@checker.id, [event.id])
      expect(@checker.reload).to be_working # Events received
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker.reload).not_to be_working # too much time has passed
    end
  end

  describe "#receive" do
    it "queues any payloads it receives" do
      event1 = Huginn::Event.new
      event1.agent = huginn_agents(:bob_rain_notifier_agent)
      event1.payload = { :data => "event1" }
      event1.save!

      event2 = Huginn::Event.new
      event2.agent = huginn_agents(:bob_weather_agent)
      event2.payload = { :data => "event2" }
      event2.save!

      Huginn::Agents::DigestAgent.async_receive(@checker.id, [event1.id, event2.id])
      expect(@checker.reload.memory[:queue]).to eq([event1.id, event2.id])
    end
  end

  describe "#check" do
    it "should emit a event" do
      expect { Huginn::Agents::DigestAgent.async_check(@checker.id) }.not_to change { Huginn::Event.count }

      event1 = Huginn::Event.new
      event1.agent = huginn_agents(:bob_rain_notifier_agent)
      event1.payload = { :data => "event" }
      event1.save!

      event2 = Huginn::Event.new
      event2.agent = huginn_agents(:bob_weather_agent)
      event2.payload = { :data => "event" }
      event2.save!

      Huginn::Agents::DigestAgent.async_receive(@checker.id, [event1.id, event2.id])
      @checker.sources << huginn_agents(:bob_rain_notifier_agent) << huginn_agents(:bob_weather_agent)
      @checker.save!

      expect { Huginn::Agents::DigestAgent.async_check(@checker.id) }.to change { Huginn::Event.count }.by(1)
      @checker.reload
      expect(@checker.most_recent_event.payload["events"]).to eq([event1.payload, event2.payload])
      expect(@checker.most_recent_event.payload["message"]).to eq("event;event")
      expect(@checker.memory[:queue]).to be_empty
    end
  end
end
