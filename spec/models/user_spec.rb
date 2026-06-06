# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "Devise modules" do
    it "includes omniauthable" do
      expect(described_class.devise_modules).to include(:omniauthable)
    end

    it "includes rememberable" do
      expect(described_class.devise_modules).to include(:rememberable)
    end

    it "includes trackable" do
      expect(described_class.devise_modules).to include(:trackable)
    end

    it "does not include database_authenticatable" do
      expect(described_class.devise_modules).not_to include(:database_authenticatable)
    end
  end

  describe "schema" do
    subject(:columns) { described_class.column_names }

    it "has an email column" do
      expect(columns).to include("email")
    end

    it "has a name column" do
      expect(columns).to include("name")
    end

    it "has an avatar_url column" do
      expect(columns).to include("avatar_url")
    end

    it "has a provider column" do
      expect(columns).to include("provider")
    end

    it "has a uid column" do
      expect(columns).to include("uid")
    end

    it "has a remember_created_at column" do
      expect(columns).to include("remember_created_at")
    end

    it "has a sign_in_count column" do
      expect(columns).to include("sign_in_count")
    end

    it "has a current_sign_in_at column" do
      expect(columns).to include("current_sign_in_at")
    end

    it "has a last_sign_in_at column" do
      expect(columns).to include("last_sign_in_at")
    end

    it "has a current_sign_in_ip column" do
      expect(columns).to include("current_sign_in_ip")
    end

    it "has a last_sign_in_ip column" do
      expect(columns).to include("last_sign_in_ip")
    end

    it "does not have an encrypted_password column" do
      expect(columns).not_to include("encrypted_password")
    end
  end

  describe "unique index on (provider, uid)" do
    it "exists on the users table" do
      indexes = ActiveRecord::Base.connection.indexes(:users)
      provider_uid_index = indexes.find do |idx|
        idx.columns == %w[provider uid]
      end

      expect(provider_uid_index).not_to be_nil
      expect(provider_uid_index.unique).to be true
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "is invalid without an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it "is invalid with a duplicate email" do
      create(:user, email: "taken@example.com")
      user = build(:user, email: "taken@example.com")
      expect(user).not_to be_valid
    end

    it "is invalid without a provider" do
      user = build(:user, provider: nil)
      expect(user).not_to be_valid
    end

    it "is invalid without a uid" do
      user = build(:user, uid: nil)
      expect(user).not_to be_valid
    end
  end

  describe "database constraints" do
    it "enforces uniqueness of (provider, uid) at the database level" do
      existing = create(:user, provider: "google_oauth2", uid: "abc123")
      duplicate = build(:user, provider: existing.provider, uid: existing.uid)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
