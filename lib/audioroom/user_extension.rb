# frozen_string_literal: true

module Audioroom
  module UserExtension
    extend ActiveSupport::Concern

    included do
      has_many :audioroom_rooms,
               class_name: "Audioroom::Room",
               foreign_key: :creator_id,
               dependent: :destroy
    end
  end
end

::User.include Audioroom::UserExtension
