# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspacePolicy, type: :policy do
  subject(:policy) { described_class.new(user, workspace) }

  let(:workspace) { create(:workspace) }

  # ---------------------------------------------------------------------------
  # Helper — build a user with a membership for the given role in workspace
  # ---------------------------------------------------------------------------
  def user_with_role(role)
    u = create(:user)
    create(:workspace_membership, user: u, workspace: workspace, role: role)
    u
  end

  # ---------------------------------------------------------------------------
  # collaborator
  # ---------------------------------------------------------------------------
  context "as collaborator" do
    let(:user) { user_with_role(:collaborator) }

    it "permits create?" do
      expect(policy.create?).to be true
    end

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "denies update?" do
      expect(policy.update?).to be false
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end

    it "denies invite?" do
      expect(policy.invite?).to be false
    end

    it "denies generate_report?" do
      expect(policy.generate_report?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # admin
  # ---------------------------------------------------------------------------
  context "as admin" do
    let(:user) { user_with_role(:admin) }

    it "permits create?" do
      expect(policy.create?).to be true
    end

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "denies update?" do
      expect(policy.update?).to be false
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be false
    end

    it "denies invite?" do
      expect(policy.invite?).to be false
    end

    it "permits generate_report?" do
      expect(policy.generate_report?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # super_admin
  # ---------------------------------------------------------------------------
  context "as super_admin" do
    let(:user) { user_with_role(:super_admin) }

    it "permits create?" do
      expect(policy.create?).to be true
    end

    it "permits show?" do
      expect(policy.show?).to be true
    end

    it "permits update?" do
      expect(policy.update?).to be true
    end

    it "permits destroy?" do
      expect(policy.destroy?).to be true
    end

    it "permits invite?" do
      expect(policy.invite?).to be true
    end

    it "permits generate_report?" do
      expect(policy.generate_report?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # non-member (user has no membership in this workspace)
  # ---------------------------------------------------------------------------
  context "as non-member" do
    let(:user) { create(:user) }

    it "permits create? (any authenticated user may create a workspace)" do
      expect(policy.create?).to be true
    end

    it "denies show?" do
      expect(policy.show?).to be false
    end

    it "denies update?" do
      expect(policy.update?).to be_falsey
    end

    it "denies destroy?" do
      expect(policy.destroy?).to be_falsey
    end

    it "denies invite?" do
      expect(policy.invite?).to be_falsey
    end

    it "denies generate_report?" do
      expect(policy.generate_report?).to be_falsey
    end
  end

  # ---------------------------------------------------------------------------
  # Scope
  # ---------------------------------------------------------------------------
  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Workspace).resolve }

    context "when the user has no workspace memberships" do
      let(:user) { create(:user) }

      it "returns an empty collection" do
        create(:workspace) # unrelated workspace
        expect(scope).to be_empty
      end
    end

    context "when the user belongs to exactly one workspace" do
      let(:user) { create(:user) }

      before { create(:workspace_membership, user: user, workspace: workspace) }

      it "returns only that workspace" do
        create(:workspace) # another workspace the user does not belong to
        expect(scope).to contain_exactly(workspace)
      end
    end

    context "when the user belongs to multiple workspaces" do
      let(:user)       { create(:user) }
      let(:workspace2) { create(:workspace) }

      before do
        create(:workspace_membership, user: user, workspace: workspace)
        create(:workspace_membership, user: user, workspace: workspace2)
      end

      it "returns all workspaces the user belongs to" do
        expect(scope).to contain_exactly(workspace, workspace2)
      end

      it "does not return duplicate workspaces" do
        results = scope.to_a
        expect(results.length).to eq(results.uniq.length)
      end
    end
  end
end
