require 'rails_helper'

describe Huginn::LogsController do
  describe "GET index" do
    it "can filter by Agent" do
      sign_in users(:bob)
      get :index, :agent_id => huginn_agents(:bob_weather_agent).id
      expect(assigns(:logs).length).to eq(huginn_agents(:bob_weather_agent).logs.length)
      expect(assigns(:logs).all? {|i| expect(i.agent).to eq(huginn_agents(:bob_weather_agent)) }).to be_truthy
    end

    it "only loads Agents owned by the current user" do
      sign_in users(:bob)
      expect {
        get :index, :agent_id => huginn_agents(:jane_weather_agent).id
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE clear" do
    it "deletes all logs for a specific Agent" do
      huginn_agents(:bob_weather_agent).last_error_log_at = 2.hours.ago
      sign_in users(:bob)
      expect {
        delete :clear, :agent_id => huginn_agents(:bob_weather_agent).id
      }.to change { Huginn::AgentLog.count }.by(-1 * huginn_agents(:bob_weather_agent).logs.count)
      expect(assigns(:logs).length).to eq(0)
      expect(huginn_agents(:bob_weather_agent).reload.logs.count).to eq(0)
      expect(huginn_agents(:bob_weather_agent).last_error_log_at).to be_nil
    end

    it "only deletes logs for an Agent owned by the current user" do
      sign_in users(:bob)
      expect {
        delete :clear, :agent_id => huginn_agents(:jane_weather_agent).id
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
