# frozen_string_literal: true

module RoomData
  COLLECTION_KEYS = %i[
    ground floor_details objects ceiling
    colliders doors lights pedestals
  ].freeze

  def self.empty_collections
    COLLECTION_KEYS.to_h { |key| [key, []] }
  end
end
