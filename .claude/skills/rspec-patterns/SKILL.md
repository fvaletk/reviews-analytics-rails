# Skill: rspec-patterns

## Setup Assumptions

- `rspec-rails`, `factory_bot_rails`, `faker` are in the Gemfile
- Factories live in `spec/factories/`
- No fixtures — factories only

## File Locations

```
spec/
  models/           # Unit tests for model validations, scopes, methods
  services/         # Unit tests for service objects
  jobs/             # Unit tests for Sidekiq jobs
  policies/         # Pundit policy specs
  requests/         # Integration tests for controllers (preferred over controller specs)
  channels/         # ActionCable channel specs
```

## Request Specs (preferred over controller specs)

```ruby
RSpec.describe "POST /workspaces/:workspace_id/apps", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }

  before { sign_in user }

  context "with valid params" do
    it "creates the app and redirects" do
      post workspace_apps_path(workspace), params: { app: { name: "MyApp", app_store_url: "..." } }
      expect(response).to redirect_to(workspace_app_path(workspace, App.last))
    end
  end

  context "when user is not a member" do
    it "returns 404" do
      other_workspace = create(:workspace)
      post workspace_apps_path(other_workspace), params: { app: { name: "x" } }
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

## Policy Specs

```ruby
RSpec.describe WorkspacePolicy, type: :policy do
  subject { described_class.new(user, workspace) }

  let(:workspace) { create(:workspace) }

  context "as super_admin" do
    let(:user) { create(:user, :super_admin_of, workspace: workspace) }
    it { is_expected.to permit_action(:invite) }
  end

  context "as collaborator" do
    let(:user) { create(:user, :collaborator_of, workspace: workspace) }
    it { is_expected.not_to permit_action(:invite) }
  end

  context "as non-member" do
    let(:user) { create(:user) }
    it { is_expected.not_to permit_action(:show) }
  end
end
```

## Rules

- One expectation per example where practical
- Use `let` not `let!` unless the record must exist before the example runs
- Stub external HTTP calls — never make real HTTP requests in specs
- Stub `LlmService` and `ScrapingService` in job specs — never hit real APIs
- Use `create` for records that must be persisted, `build` for records that don't

```ruby
# Stubbing external services in job specs
before do
  allow(ScrapingService).to receive(:fetch).and_return({ "reviews" => [...] })
  allow(LlmService).to receive(:analyze).and_return({ "summary" => "..." })
end
```

## Factories (minimal examples)

```ruby
FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    provider { "google_oauth2" }
    uid { SecureRandom.hex }
  end

  factory :workspace do
    name { Faker::Company.name }
  end

  factory :workspace_membership do
    user
    workspace
    role { :admin }
    joined_at { Time.current }
  end
end
```