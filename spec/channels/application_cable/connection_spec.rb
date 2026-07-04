# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }

  it "identifies the connection by the warden-authenticated user" do
    warden = instance_double(Warden::Proxy, user: user)

    connect "/cable", env: { "warden" => warden }

    expect(connection.current_user).to eq(user)
  end

  it "rejects the connection when warden has no authenticated user" do
    warden = instance_double(Warden::Proxy, user: nil)

    expect { connect "/cable", env: { "warden" => warden } }.to have_rejected_connection
  end
end
