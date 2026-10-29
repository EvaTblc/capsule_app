require "rails_helper"

RSpec.describe ExternalApi do
  let(:http_client) { double("http client") }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body.to_json, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  before do
    allow(HTTP).to receive(:timeout).with(10).and_return(http_client)
    allow(http_client).to receive(:headers).and_return(http_client)
  end

  it "google_books : la clé de l'appli est ajoutée aux paramètres de la recherche" do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:google, :books_api_key).and_return("CLE")
    expect(http_client).to receive(:get)
      .with("https://www.googleapis.com/books/v1/volumes", params: { q: "dune", maxResults: 5, key: "CLE" })
      .and_return(fake_response(200, { items: [] }))

    expect(described_class.google_books(q: "dune", maxResults: 5)).to eq("items" => [])
  end

  it "API en erreur : ExternalApi::Error, qui nomme l'API sans reprendre sa réponse" do
    allow(http_client).to receive(:get).and_return(fake_response(401, { status_message: "Invalid API key: SECRET123" }))

    expect { described_class.tmdb("search/movie", query: "x") }
      .to raise_error(ExternalApi::Error, "api.themoviedb.org a répondu 401 Unauthorized")
  end
end
