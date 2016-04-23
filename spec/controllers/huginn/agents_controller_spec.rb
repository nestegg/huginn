require 'rails_helper'

describe Huginn::AgentsController do
  def valid_attributes(options = {})
    {
        :type => "Huginn::Agents::WebsiteAgent",
        :name => "Something",
        :options => huginn_agents(:bob_website_agent).options,
        :source_ids => [huginn_agents(:bob_weather_agent).id, ""]
    }.merge(options)
  end

  describe "GET index" do
    it "only returns Agents for the current user" do
      sign_in users(:bob)
      get :index
      expect(assigns(:agents).all? {|i| expect(i.user).to eq(users(:bob)) }).to be_truthy
    end
  end

  describe "POST handle_details_post" do
    it "passes control to handle_details_post on the agent" do
      sign_in users(:bob)
      post :handle_details_post, :id => huginn_agents(:bob_manual_event_agent).to_param, :payload => { :foo => "bar" }.to_json
      expect(JSON.parse(response.body)).to eq({ "success" => true })
      expect(huginn_agents(:bob_manual_event_agent).events.last.payload).to eq({ 'foo' => "bar" })
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :handle_details_post, :id => huginn_agents(:bob_manual_event_agent).to_param, :payload => { :foo => :bar }.to_json
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST run" do
    it "triggers Agent.async_check with the Agent's ID" do
      sign_in users(:bob)
      mock(Huginn::Agent).async_check(huginn_agents(:bob_manual_event_agent).id)
      post :run, :id => huginn_agents(:bob_manual_event_agent).to_param
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :run, :id => huginn_agents(:bob_manual_event_agent).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST remove_events" do
    it "deletes all events created by the given Agent" do
      sign_in users(:bob)
      agent_event = huginn_events(:bob_website_agent_event).id
      other_event = huginn_events(:jane_website_agent_event).id
      post :remove_events, :id => huginn_agents(:bob_website_agent).to_param
      expect(Huginn::Event.where(:id => agent_event).count).to eq(0)
      expect(Huginn::Event.where(:id => other_event).count).to eq(1)
    end

    it "can only be accessed by the Agent's owner" do
      sign_in users(:jane)
      expect {
        post :remove_events, :id => huginn_agents(:bob_website_agent).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST propagate" do
    it "runs event propagation for all Agents" do
      sign_in users(:bob)
      mock.proxy(Huginn::Agent).receive!
      post :propagate
    end
  end

  describe "GET show" do
    it "only shows Agents for the current user" do
      sign_in users(:bob)
      get :show, :id => huginn_agents(:bob_website_agent).to_param
      expect(assigns(:agent)).to eq(huginn_agents(:bob_website_agent))

      expect {
        get :show, :id => huginn_agents(:jane_website_agent).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET new" do
    describe "with :id" do
      it "opens a clone of a given Agent" do
        sign_in users(:bob)
        get :new, :id => huginn_agents(:bob_website_agent).to_param
        expect(assigns(:agent).attributes).to eq(users(:bob).agents.build_clone(huginn_agents(:bob_website_agent)).attributes)
      end

      it "only allows the current user to clone his own Agent" do
        sign_in users(:bob)

        expect {
          get :new, :id => huginn_agents(:jane_website_agent).to_param
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "with a scenario_id" do
      it 'populates the assigned agent with the scenario' do
        sign_in users(:bob)
        get :new, :scenario_id => huginn_scenarios(:bob_weather).id
        expect(assigns(:agent).scenario_ids).to eq([huginn_scenarios(:bob_weather).id])
      end

      it "does not see other user's scenarios" do
        sign_in users(:bob)
        get :new, :scenario_id => huginn_scenarios(:jane_weather).id
        expect(assigns(:agent).scenario_ids).to eq([])
      end
    end
  end

  describe "GET edit" do
    it "only shows Agents for the current user" do
      sign_in users(:bob)
      get :edit, :id => huginn_agents(:bob_website_agent).to_param
      expect(assigns(:agent)).to eq(huginn_agents(:bob_website_agent))

      expect {
        get :edit, :id => huginn_agents(:jane_website_agent).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST create" do
    it "errors on bad types" do
      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:type => "Huginn::Agents::ThisIsFake")
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Huginn::Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)

      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:type => "Object")
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Huginn::Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)
      sign_in users(:bob)

      expect {
        post :create, :agent => valid_attributes(:type => "Huginn::Agent")
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Huginn::Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)

      expect {
        post :create, :agent => valid_attributes(:type => "User")
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to be_a(Huginn::Agent)
      expect(assigns(:agent)).to have(1).error_on(:type)
    end

    it "creates Agents for the current user" do
      sign_in users(:bob)
      expect {
        expect {
          post :create, :agent => valid_attributes
        }.to change { users(:bob).agents.count }.by(1)
      }.to change { Huginn::Link.count }.by(1)
      expect(assigns(:agent)).to be_a(Huginn::Agents::WebsiteAgent)
    end

    it "shows errors" do
      sign_in users(:bob)
      expect {
        post :create, :agent => valid_attributes(:name => "")
      }.not_to change { users(:bob).agents.count }
      expect(assigns(:agent)).to have(1).errors_on(:name)
      expect(response).to render_template("new")
    end

    it "will not accept Agent sources owned by other users" do
      sign_in users(:bob)
      expect {
        expect {
          post :create, :agent => valid_attributes(:source_ids => [huginn_agents(:jane_weather_agent).id])
        }.not_to change { users(:bob).agents.count }
      }.not_to change { Huginn::Link.count }
    end
  end

  describe "PUT update" do
    it "does not allow changing types" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:type => "Huginn::Agents::WeatherAgent")
      expect(assigns(:agent)).to have(1).errors_on(:type)
      expect(response).to render_template("edit")
    end

    it "updates attributes on Agents for the current user" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name")
      expect(response).to redirect_to(huginn_agents_path)
      expect(huginn_agents(:bob_website_agent).reload.name).to eq("New name")

      expect {
        post :update, :id => huginn_agents(:jane_website_agent).to_param, :agent => valid_attributes(:name => "New name")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "accepts JSON requests" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :format => :json
      expect(huginn_agents(:bob_website_agent).reload.name).to eq("New name")
      expect(JSON.parse(response.body)['name']).to eq("New name")
      expect(response).to be_success
    end

    it "will not accept Agent sources owned by other users" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:source_ids => [huginn_agents(:jane_weather_agent).id])
      expect(assigns(:agent)).to have(1).errors_on(:sources)
    end

    it "will not accept Scenarios owned by other users" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:scenario_ids => [huginn_scenarios(:jane_weather).id])
      expect(assigns(:agent)).to have(1).errors_on(:scenarios)
    end

    it "shows errors" do
      sign_in users(:bob)
      post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "")
      expect(assigns(:agent)).to have(1).errors_on(:name)
      expect(response).to render_template("edit")
    end

    describe "redirecting back" do
      before do
        sign_in users(:bob)
      end

      it "can redirect back to the show path" do
        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "show"
        expect(response).to redirect_to(huginn_agent_path(huginn_agents(:bob_website_agent)))
      end

      it "redirect back to the index path by default" do
        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name")
        expect(response).to redirect_to(huginn_agents_path)
      end

      it "accepts return paths to scenarios" do
        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "/huginn/scenarios/2"
        expect(response).to redirect_to("/huginn/scenarios/2")
      end

      it "sanitizes return paths" do
        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "/scenar"
        expect(response).to redirect_to(huginn_agents_path)

        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "http://google.com"
        expect(response).to redirect_to(huginn_agents_path)

        post :update, :id => huginn_agents(:bob_website_agent).to_param, :agent => valid_attributes(:name => "New name"), :return => "javascript:alert(1)"
        expect(response).to redirect_to(huginn_agents_path)
      end
    end

    it "updates last_checked_event_id when drop_pending_events is given" do
      sign_in users(:bob)
      agent = huginn_agents(:bob_website_agent)
      agent.disabled = true
      agent.last_checked_event_id = nil
      agent.save!
      post :update, id: huginn_agents(:bob_website_agent).to_param, agent: { disabled: 'false', drop_pending_events: 'true' }
      agent.reload
      expect(agent.disabled).to eq(false)
      expect(agent.last_checked_event_id).to eq(Huginn::Event.maximum(:id))
    end
  end

  describe "PUT leave_scenario" do
    it "removes an Agent from the given Scenario for the current user" do
      sign_in users(:bob)

      expect(huginn_agents(:bob_weather_agent).scenarios).to include(huginn_scenarios(:bob_weather))
      put :leave_scenario, :id => huginn_agents(:bob_weather_agent).to_param, :scenario_id => huginn_scenarios(:bob_weather).to_param
      expect(huginn_agents(:bob_weather_agent).scenarios).not_to include(huginn_scenarios(:bob_weather))

      expect(Huginn::Scenario.where(:id => huginn_scenarios(:bob_weather).id)).to exist

      expect {
        put :leave_scenario, :id => huginn_agents(:jane_weather_agent).to_param, :scenario_id => huginn_scenarios(:jane_weather).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "DELETE destroy" do
    it "destroys only Agents owned by the current user" do
      sign_in users(:bob)
      expect {
        delete :destroy, :id => huginn_agents(:bob_website_agent).to_param
      }.to change(Huginn::Agent, :count).by(-1)

      expect {
        delete :destroy, :id => huginn_agents(:jane_website_agent).to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "redirects correctly when the Agent is deleted from the Agent itself" do
      sign_in users(:bob)

      delete :destroy, :id => huginn_agents(:bob_website_agent).to_param
      expect(response).to redirect_to huginn_agents_path
    end

    it "redirects correctly when the Agent is deleted from a Scenario" do
      sign_in users(:bob)

      delete :destroy, :id => huginn_agents(:bob_weather_agent).to_param, :return => huginn_scenario_path(huginn_scenarios(:bob_weather)).to_param
      expect(response).to redirect_to huginn_scenario_path(huginn_scenarios(:bob_weather))
    end
  end

  describe "#form_configurable actions" do
    before(:each) do
      @params = {attribute: 'auth_token', agent: valid_attributes(:type => "Huginn::Agents::HipchatAgent", options: {auth_token: '12345'})}
      sign_in users(:bob)
    end
    describe "POST validate" do

      it "returns with status 200 when called with a valid option" do
        any_instance_of(Huginn::Agents::HipchatAgent) do |klass|
          stub(klass).validate_option { true }
        end

        post :validate, @params
        expect(response.status).to eq 200
      end

      it "returns with status 403 when called with an invalid option" do
        any_instance_of(Huginn::Agents::HipchatAgent) do |klass|
          stub(klass).validate_option { false }
        end

        post :validate, @params
        expect(response.status).to eq 403
      end
    end

    describe "POST complete" do
      it "callsAgent#complete_option and renders json" do
        any_instance_of(Huginn::Agents::HipchatAgent) do |klass|
          stub(klass).complete_option { [{name: 'test', value: 1}] }
        end

        post :complete, @params
        expect(response.status).to eq 200
        expect(response.header['Content-Type']).to include('application/json')

      end
    end
  end

  describe "POST dry_run" do
    before do
      stub_request(:any, /xkcd/).to_return(body: File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), status: 200)
    end

    it "does not actually create any agent, event or log" do
      sign_in users(:bob)
      expect {
        post :dry_run, agent: valid_attributes()
      }.not_to change {
        [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count]
      }
      json = JSON.parse(response.body)
      expect(json['log']).to be_a(String)
      expect(json['events']).to be_a(String)
      expect(JSON.parse(json['events']).map(&:class)).to eq([Hash])
      expect(json['memory']).to be_a(String)
      expect(JSON.parse(json['memory'])).to be_a(Hash)
    end

    it "does not actually update an agent" do
      sign_in users(:bob)
      agent = huginn_agents(:bob_weather_agent)
      expect {
        post :dry_run, id: agent, agent: valid_attributes(name: 'New Name')
      }.not_to change {
        [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count, agent.name, agent.updated_at]
      }
    end

    it "accepts an event" do
      sign_in users(:bob)
      agent = huginn_agents(:bob_website_agent)
      agent.options['url_from_event'] = '{{ url }}'
      agent.save!
      url_from_event = "http://xkcd.com/?from_event=1".freeze
      expect {
        post :dry_run, id: agent, event: { url: url_from_event }
      }.not_to change {
        [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count, agent.name, agent.updated_at]
      }
      json = JSON.parse(response.body)
      expect(json['log']).to match(/^\[\d\d:\d\d:\d\d\] INFO -- : Fetching #{Regexp.quote(url_from_event)}$/)
    end
  end

  describe "DELETE memory" do
    it "clears memory of the agent" do
      agent = huginn_agents(:bob_website_agent)
      agent.update!(memory: { "test" => 42 })
      sign_in users(:bob)
      delete :destroy_memory, id: agent.to_param
      expect(agent.reload.memory).to eq({})
    end

    it "does not clear memory of an agent not owned by the current user" do
      agent = huginn_agents(:jane_website_agent)
      agent.update!(memory: { "test" => 42 })
      sign_in users(:bob)
      expect {
        delete :destroy_memory, id: agent.to_param
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(agent.reload.memory).to eq({ "test" => 42})
    end
  end
end
