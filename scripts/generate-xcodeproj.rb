#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"
require "fileutils"

module DeterministicXcodeUUIDs
  def generate_available_uuid_list(count = 100)
    @deterministic_uuid_counter ||= 0
    new_uuids = Array.new(count) do
      @deterministic_uuid_counter += 1
      format("%024X", @deterministic_uuid_counter)
    end
    uniques = new_uuids - (@generated_uuids + uuids)
    @generated_uuids += uniques
    @available_uuids += uniques
  end
end

Xcodeproj::Project.prepend(DeterministicXcodeUUIDs)

root = File.expand_path("..", __dir__)
project_path = File.join(root, "PulseDock.xcodeproj")
legacy_project_path = File.join(root, "SystemDashboard.xcodeproj")
FileUtils.rm_rf(project_path)
FileUtils.rm_rf(legacy_project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.development_region = "en"
project.root_object.known_regions = ["en", "zh-Hans", "Base"]

shared_group = project.new_group("SharedMetrics", "Sources/SharedMetrics")
app_group = project.new_group("PulseDockApp", "Sources/PulseDockApp")
widget_group = project.new_group("PulseDockWidget", "Sources/PulseDockWidget")
resources_group = project.new_group("Resources", "Resources")

shared_files = Dir.glob(File.join(root, "Sources/SharedMetrics/*.swift")).sort.map { |path| shared_group.new_file(path) }
app_files = Dir.glob(File.join(root, "Sources/PulseDockApp/*.swift")).sort.map { |path| app_group.new_file(path) }
widget_files = Dir.glob(File.join(root, "Sources/PulseDockWidget/*.swift")).sort.map { |path| widget_group.new_file(path) }

shared_resource_files = [
  "Sources/SharedMetrics/Resources/en.lproj/SharedMetrics.strings",
  "Sources/SharedMetrics/Resources/zh-Hans.lproj/SharedMetrics.strings"
].map { |path| shared_group.new_file(File.join(root, path)) }
app_resource_files = [
  "Sources/PulseDockApp/Resources/PulseDockApp.xcstrings",
  "Resources/App/en.lproj/InfoPlist.strings",
  "Resources/App/zh-Hans.lproj/InfoPlist.strings"
].map { |path| resources_group.new_file(File.join(root, path)) }
widget_resource_files = [
  "Sources/PulseDockWidget/Resources/PulseDockWidget.xcstrings",
  "Resources/Widget/en.lproj/InfoPlist.strings",
  "Resources/Widget/zh-Hans.lproj/InfoPlist.strings"
].map { |path| resources_group.new_file(File.join(root, path)) }

app_info = resources_group.new_file(File.join(root, "Resources/AppInfo.plist"))
widget_info = resources_group.new_file(File.join(root, "Resources/WidgetInfo.plist"))
app_entitlements = resources_group.new_file(File.join(root, "Resources/PulseDock.entitlements"))
widget_entitlements = resources_group.new_file(File.join(root, "Resources/PulseDockWidgetExtension.entitlements"))
app_privacy_manifest = resources_group.new_file(File.join(root, "Resources/App/PrivacyInfo.xcprivacy"))
widget_privacy_manifest = resources_group.new_file(File.join(root, "Resources/Widget/PrivacyInfo.xcprivacy"))
app_icon = resources_group.new_file(File.join(root, "Resources/AppIcon.icns"))

deployment_target = "14.0"
app_bundle_identifier = ENV.fetch("APP_BUNDLE_IDENTIFIER", "com.ifonly3.pulsedock")
widget_bundle_identifier = ENV.fetch("WIDGET_BUNDLE_IDENTIFIER", "#{app_bundle_identifier}.widget")
marketing_version = ENV.fetch("MARKETING_VERSION", "1.0.0")
current_project_version = ENV.fetch("CURRENT_PROJECT_VERSION", "1")
development_team = ENV.fetch("DEVELOPMENT_TEAM", "")

app_target = project.new_target(:application, "PulseDock", :osx, deployment_target)
widget_target = project.new_target(:app_extension, "PulseDockWidgetExtension", :osx, deployment_target)
app_target.product_reference.path = "Pulse Dock.app"
widget_target.product_reference.path = "PulseDockWidgetExtension.appex"

(shared_files + app_files).each { |file| app_target.add_file_references([file]) }
(shared_files + widget_files).each { |file| widget_target.add_file_references([file]) }
app_target.add_resources(shared_resource_files + app_resource_files + [app_privacy_manifest, app_icon])
widget_target.add_resources(shared_resource_files + widget_resource_files + [widget_privacy_manifest])

app_target.add_system_framework("SwiftUI")
app_target.add_system_framework("AppKit")
app_target.add_system_framework("WidgetKit")
app_target.add_system_framework("CoreGraphics")
app_target.add_system_framework("IOKit")
app_target.add_system_framework("Metal")
app_target.add_system_framework("Network")
app_target.add_system_framework("SystemConfiguration")
widget_target.add_system_framework("SwiftUI")
widget_target.add_system_framework("WidgetKit")
widget_target.add_system_framework("CoreGraphics")
widget_target.add_system_framework("IOKit")
widget_target.add_system_framework("Metal")
widget_target.add_system_framework("Network")
widget_target.add_system_framework("SystemConfiguration")

copy_phase = app_target.new_copy_files_build_phase("Embed App Extensions")
copy_phase.symbol_dst_subfolder_spec = :plug_ins
copy_phase.add_file_reference(widget_target.product_reference, true)

app_target.add_dependency(widget_target)

project.targets.each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = development_team
    settings["MACOSX_DEPLOYMENT_TARGET"] = deployment_target
    settings["MARKETING_VERSION"] = marketing_version
    settings["CURRENT_PROJECT_VERSION"] = current_project_version
    settings["SWIFT_VERSION"] = "6.0"
    settings["ENABLE_HARDENED_RUNTIME"] = "YES"
    settings["GENERATE_INFOPLIST_FILE"] = "NO"
    settings["INFOPLIST_FILE"] = target == app_target ? "Resources/AppInfo.plist" : "Resources/WidgetInfo.plist"
    settings["CODE_SIGN_ENTITLEMENTS"] = target == app_target ? "Resources/PulseDock.entitlements" : "Resources/PulseDockWidgetExtension.entitlements"
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = target == app_target ? app_bundle_identifier : widget_bundle_identifier
    settings["PRODUCT_NAME"] = target == app_target ? "Pulse Dock" : "PulseDockWidgetExtension"
    settings.reject! { |key, _| key.start_with?("ASSETCATALOG_COMPILER_") }
  end
end

project.sort

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_build_target(widget_target)
scheme.set_launch_target(app_target)
scheme.archive_action.build_configuration = "Release"

project.save
scheme.save_as(project.path, "PulseDock", true)
puts project_path
