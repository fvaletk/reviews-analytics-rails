# frozen_string_literal: true

class User < ApplicationRecord
  devise :omniauthable, :rememberable, :trackable,
         omniauth_providers: [:google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :uid, presence: true
end
