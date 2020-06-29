# File:
#   modules/AutoinstClone.ycp
#
# Package:
#   Autoinstallation Configuration System
#
# Summary:
#   Create a control file from an exisiting machine
#
# Authors:
#   Anas Nashif <nashif@suse.de>
#
# $Id$
#
#
require "yast"
require "y2storage"

module Yast
  # This module drives the AutoYaST cloning process
  class AutoinstCloneClass < Module
    include Yast::Logger

    def main
      Yast.import "Mode"
      Yast.import "Call"
      Yast.import "Profile"
      Yast.import "Y2ModuleConfig"
      Yast.import "AutoinstConfig"
      Yast.import "Report"

      Yast.include self, "autoinstall/xml.rb"

      # aditional configuration resources o be cloned
      @additional = []
    end

    # Create a list of clonable resources
    #
    # @return [Array<Yast::Term>] list to be used in widgets (sorted by its label)
    def createClonableList
      module_map = Y2ModuleConfig.ModuleMap
      clonable_items = module_map.each_with_object([]) do |(def_resource, resource_map), items|
        log.debug "r: #{def_resource} => #{resource_map["X-SuSE-YaST-AutoInstClonable"]}"
        clonable = resource_map["X-SuSE-YaST-AutoInstClonable"] == "true"
        next unless clonable

        desktop_file = resource_map.fetch("X-SuSE-DocTeamID", "").slice(4..-1)
        translation_key = "Name(#{desktop_file}.desktop): #{resource_map["Name"]}"
        name = Builtins.dpgettext("desktop_translations", "/usr/share/locale/", translation_key)
        name = resource_map.fetch("Name", "") if name == translation_key
        # Set resource name, if not using default value
        resource_name = resource_map.fetch("X-SuSE-YaST-AutoInstResource", "")
        resource_name = def_resource if resource_name.empty?
        items << Item(Id(resource_name), name)
      end

      clonable_items.sort_by { |i| i[1] }
    end

    # Builds the profile
    #
    # @param target [Symbol] How much information to include in the profile (:default, :compact)
    # @return [void] returns void and sets profile in ProfileClass.current
    # @see ProfileClass.create
    # @see ProfileClass.current for result
    # @see ProfileClass.Prepare
    def Process(target: :default)
      log.info "Additional resources: #{@additional}"
      Mode.SetMode("autoinst_config")

      Y2ModuleConfig.ModuleMap.each do |def_resource, resource_map|
        # Set resource name, if not using default value
        resource = resource_map.fetch("X-SuSE-YaST-AutoInstResource", "")
        resource = def_resource if resource.empty?

        next unless @additional.include?(resource)

        time_start = Time.now
        read_module(resource_map)
        log.info "Cloning #{resource} took: #{(Time.now - time_start).round} sec"
      end

      Call.Function("general_auto", ["Import", General()]) if @additional.include?("general")

      Profile.create(@additional, target: target)
      nil
    end

    publish variable: :additional, type: "list <string>"
    publish function: :createClonableList, type: "list ()"
    publish function: :Process, type: "void ()"

  private

    # Detects whether the current system uses multipath
    # @return [Boolean] if in use
    def multipath_in_use?
      !Y2Storage::StorageManager.instance.probed.multipaths.empty?
    end

    # General options
    #
    # @return [Hash] general options
    def General
      Yast.import "Mode"
      Mode.SetMode("normal")

      general = {}
      general["mode"] = { "confirm" => false }
      general["storage"] = { "start_multipath" => true } if multipath_in_use?

      Mode.SetMode("autoinst_config")
      general
    end

    # Reads module if it is appropriate
    #
    # @param resource_map [Hash] resources map
    # @return [void]
    def read_module(resource_map)
      auto = Ops.get_string(resource_map, "X-SuSE-YaST-AutoInstClient", "")

      # Do not read settings from system in first stage, autoyast profile
      # should contain only proposed and user modified values.
      # Exception: Storage and software module have autoyast modules which are
      #            defined in autoyast itself.
      #            So, these modules have to be called.
      if !Stage.initial ||
          ["software_auto", "storage_auto"].include?(auto)
        Call.Function(auto, ["Read"])
      end
    end
  end

  AutoinstClone = AutoinstCloneClass.new
  AutoinstClone.main
end
