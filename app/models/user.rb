# frozen_string_literal: true

class User < ApplicationRecord
  devise :omniauthable, :rememberable, :trackable,
         omniauth_providers: [:google_oauth2]

  has_many :workspace_memberships, dependent: :destroy
  has_many :workspaces, through: :workspace_memberships

  validates :email, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :uid, presence: true

  def self.from_omniauth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.email = auth.info.email
    user.name = auth.info.name
    user.avatar_url = auth.info.image
    user.save!
    user
  end
end
