require 'rails_helper'

describe Huginn::Agents::PdfInfoAgent do
  let(:agent) do
    _agent = Huginn::Agents::PdfInfoAgent.new(name: "PDF Info Agent")
    _agent.user = users(:bob)
    _agent.sources << huginn_agents(:bob_website_agent)
    _agent.save!
    _agent
  end

  describe "#receive" do
    before do
      @event = Huginn::Event.new(payload: {'url' => 'http://mypdf.com'})
    end

    it "should call HyPDF" do
      expect {
        mock(agent).open('http://mypdf.com') { "data" }
        mock(HyPDF).pdfinfo('data') { {title: "Huginn"} }
        agent.receive([@event])
      }.to change { Huginn::Event.count }.by(1)
      event = Huginn::Event.last
      expect(event.payload[:title]).to eq('Huginn')
    end
  end
end
