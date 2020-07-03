# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "singleton"
require "autoinstall/entries/description"

Yast.import "Desktop"

module Y2Autoinstallation
  module Entries
    # Represents registry holding descriptions and groups
    class Registry
      include Singleton

      # Gets list of all known descriptions
      # @return [Description]
      def descriptions
        read unless @read

        @descriptions
      end

      # Gets list of all descriptions that can be configured
      # @return [Description]
      def configurable_descriptions
        descriptions.select { |d| ["all", "configure"].include?(d.mode) }
      end

      # Gets list of all descriptions that can be written
      # @return [Description]
      def writable_descriptions
        descriptions.select { |d| ["all", "write"].include?(d.mode) }
      end

      # Gets map of groups
      # @see Yast::Desktop.Groups for details
      # @return [Hash<String, Hash>] map of groups with names as keys and attributes as values
      def groups
        read unless @read

        @groups
      end

    private

      def read
        Yast::Desktop.AgentPath = Yast::Path.new(".autoyast2.desktop")
        Yast::Desktop.Read(Description::USED_VALUES)
        @descriptions = Yast::Desktop.Modules.map { |k, v| Description.new(v, k) }
        @groups = Yast::Desktop.Groups

        @read = true
      end
    end
  end
end
