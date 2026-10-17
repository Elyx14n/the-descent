# frozen_string_literal: true

module Descent
  # Plain generated geometry. This file also runs in the host-Ruby build task.
  module OccluderData
    PATH = 'data/occluders.json'

    class << self
      # FNV-1a detects stale source files, not malicious modifications.
      def fingerprint(contents)
        value = 2_166_136_261
        contents.each_byte { |byte| value = ((value ^ byte) * 16_777_619) & 0xffffffff }
        value
      end

      def load(gtk)
        contents = gtk.read_file(PATH)
        raise ArgumentError, "Missing #{PATH}; run bin/rake assets:occluders" unless contents

        data = gtk.parse_json(contents)
        unless data.is_a?(Hash) && data['format_version'] == 4 && data['coordinate_origin'] == 'bottom_left'
          raise ArgumentError, 'Unsupported occluder data; run bin/rake assets:occluders'
        end

        data.fetch('tilesets').each do |tileset|
          image = tileset.fetch('image')
          source = gtk.read_file(image)
          next if source && fingerprint(source) == tileset['fingerprint']

          raise ArgumentError, "Outdated occluders for #{image}; run bin/rake assets:occluders, then press R"
        end
        data
      end
    end
  end
end
