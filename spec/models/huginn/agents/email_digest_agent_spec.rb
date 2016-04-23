require 'rails_helper'

describe Huginn::Agents::EmailDigestAgent do
  it_behaves_like Huginn::EmailConcern

  def get_message_part(mail, content_type)
    mail.body.parts.find { |p| p.content_type.match content_type }.body.raw_source
  end

  before do
    @checker = Huginn::Agents::EmailDigestAgent.new(:name => "something", :options => { :expected_receive_period_in_days => "2", :subject => "something interesting" })
    @checker.user = users(:bob)
    @checker.save!

    @checker1 = Huginn::Agents::EmailDigestAgent.new(:name => "something", :options => { :expected_receive_period_in_days => "2", :subject => "something interesting", :content_type => "text/plain" })
    @checker1.user = users(:bob)
    @checker1.save!
  end

  after do
    ActionMailer::Base.deliveries = []
  end

  describe "#receive" do
    it "queues any payloads it receives" do
      event1 = Huginn::Event.new
      event1.agent = huginn_agents(:bob_rain_notifier_agent)
      event1.payload = { :data => "Something you should know about" }
      event1.save!

      event2 = Huginn::Event.new
      event2.agent = huginn_agents(:bob_weather_agent)
      event2.payload = { :data => "Something else you should know about" }
      event2.save!

      Huginn::Agents::EmailDigestAgent.async_receive(@checker.id, [event1.id, event2.id])
      expect(@checker.reload.memory[:queue]).to eq([{ 'data' => "Something you should know about" }, { 'data' => "Something else you should know about" }])
    end
  end

  describe "#check" do

    it "should send an email" do
      Huginn::Agents::EmailDigestAgent.async_check(@checker.id)
      expect(ActionMailer::Base.deliveries).to eq([])

      @checker.memory[:queue] = [{ :data => "Something you should know about" },
                                 { :title => "Foo", :url => "http://google.com", :bar => 2 },
                                 { "message" => "hi", :woah => "there" },
                                 { "test" => 2 }]
      @checker.memory[:events] = [1,2,3,4]
      @checker.save!

      Huginn::Agents::EmailDigestAgent.async_check(@checker.id)

      expect(ActionMailer::Base.deliveries.last.to).to eq(["bob@example.com"])
      expect(ActionMailer::Base.deliveries.last.subject).to eq("something interesting")
      expect(get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip).to eq("Event\n  data: Something you should know about\n\nFoo\n  bar: 2\n  url: http://google.com\n\nhi\n  woah: there\n\nEvent\n  test: 2")
      expect(@checker.reload.memory[:queue]).to be_empty
    end

    it "logs and re-raises mailer errors" do
      mock(SystemMailer).send_message(anything) { raise Net::SMTPAuthenticationError.new("Wrong password") }

      @checker.memory[:queue] = [{ :data => "Something you should know about" }]
      @checker.memory[:events] = [1]
      @checker.save!

      expect {
        Huginn::Agents::EmailDigestAgent.async_check(@checker.id)
      }.to raise_error(/Wrong password/)

      expect(@checker.reload.memory[:events]).not_to be_empty
      expect(@checker.reload.memory[:queue]).not_to be_empty

      expect(@checker.logs.last.message).to match(/Error sending digest mail .* Wrong password/)
    end

    it "can receive complex events and send them on" do
      stub_request(:any, /wunderground/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/weather.json")), :status => 200)
      stub.any_instance_of(Huginn::Agents::WeatherAgent).is_tomorrow?(anything) { true }
      @checker.sources << huginn_agents(:bob_weather_agent)

      Huginn::Agent.async_check(huginn_agents(:bob_weather_agent).id)

      Huginn::Agent.receive!
      expect(@checker.reload.memory[:queue]).not_to be_empty

      Huginn::Agents::EmailDigestAgent.async_check(@checker.id)

      plain_email_text = get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip
      html_email_text = get_message_part(ActionMailer::Base.deliveries.last, /html/).strip

      expect(plain_email_text).to match(/avehumidity/)
      expect(html_email_text).to match(/avehumidity/)

      expect(@checker.reload.memory[:queue]).to be_empty
    end

    it "should send email with correct content type" do
      Huginn::Agents::EmailDigestAgent.async_check(@checker1.id)
      expect(ActionMailer::Base.deliveries).to eq([])

      @checker1.memory[:queue] = [{ :data => "Something you should know about" },
                                 { :title => "Foo", :url => "http://google.com", :bar => 2 },
                                 { "message" => "hi", :woah => "there" },
                                 { "test" => 2 }]
      @checker1.memory[:events] = [1,2,3,4]
      @checker1.save!

      Huginn::Agents::EmailDigestAgent.async_check(@checker1.id)
      expect(ActionMailer::Base.deliveries.last.content_type).to eq("text/plain; charset=UTF-8")
    end
  end
end
