#!/usr/bin/env ruby
# frozen_string_literal: true

# add-bridge-target.rb
#
# Idempotently adds the `AiyuTermHookBridge` Command Line Tool target
# to AiyuTerm.xcodeproj, configures build settings for an ad-hoc-signed
# universal macOS CLI, wires AiyuTermHookBridge/main.swift as its sole
# source file, and adds a Copy Files build phase on the AiyuTerm app
# target that embeds the compiled bridge binary at
# Contents/Helpers/aiyuterm-hook-bridge.
#
# Usage:
#   scripts/add-bridge-target.rb          # apply changes
#   scripts/add-bridge-target.rb --check  # dry-run: report what would change
#
# Safe to run repeatedly. Every mutation checks for existing state first.

require "xcodeproj"
require "pathname"

REPO_ROOT = Pathname.new(__dir__).parent.expand_path
PROJECT_PATH = REPO_ROOT + "AiyuTerm.xcodeproj"
BRIDGE_DIR = REPO_ROOT + "AiyuTermHookBridge"
BRIDGE_SOURCE = BRIDGE_DIR + "main.swift"
BRIDGE_TARGET_NAME = "AiyuTermHookBridge"
BRIDGE_PRODUCT_NAME = "aiyuterm-hook-bridge"
APP_TARGET_NAME = "AiyuTerm"
COPY_FILES_PHASE_NAME = "Embed Agent Hook Bridge"
MIN_MACOS = "14.6"
BRIDGE_BUNDLE_ID = "com.aiyuai.aiyuterm.hook-bridge"

check_only = ARGV.include?("--check")

abort "Project not found at #{PROJECT_PATH}" unless PROJECT_PATH.exist?
abort "Bridge source not found at #{BRIDGE_SOURCE}" unless BRIDGE_SOURCE.exist?

project = Xcodeproj::Project.open(PROJECT_PATH.to_s)

# ---------------------------------------------------------------------
# Step 1: ensure bridge target exists
# ---------------------------------------------------------------------

bridge_target = project.native_targets.find { |t| t.name == BRIDGE_TARGET_NAME }

if bridge_target.nil?
  puts "[add] creating target #{BRIDGE_TARGET_NAME}"
  bridge_target = project.new_target(
    :command_line_tool,
    BRIDGE_TARGET_NAME,
    :osx,
    MIN_MACOS
  )
else
  puts "[skip] target #{BRIDGE_TARGET_NAME} already exists"
end

# Set product name to the kebab-case binary name
bridge_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_NAME"] = BRIDGE_PRODUCT_NAME
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = BRIDGE_BUNDLE_ID
  config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = MIN_MACOS
  config.build_settings["ARCHS"] = "$(ARCHS_STANDARD)"
  config.build_settings["ONLY_ACTIVE_ARCH"] = config.name == "Debug" ? "YES" : "NO"
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["CODE_SIGN_IDENTITY"] = "-"
  config.build_settings["CODE_SIGNING_ALLOWED"] = "YES"
  config.build_settings["CODE_SIGNING_REQUIRED"] = "NO"
  config.build_settings["SKIP_INSTALL"] = "YES"
  config.build_settings["ALWAYS_SEARCH_USER_PATHS"] = "NO"
  config.build_settings["CLANG_ANALYZER_NONNULL"] = "YES"
  config.build_settings["CLANG_ENABLE_MODULES"] = "YES"
  config.build_settings["ENABLE_HARDENED_RUNTIME"] = "YES"
  # The bridge is a 86KB CLI; we do not need app intents / launch services.
  config.build_settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "NO"
  config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] =
    config.name == "Debug" ? "DEBUG" : ""
  config.build_settings["GCC_OPTIMIZATION_LEVEL"] =
    config.name == "Debug" ? "0" : "s"
  config.build_settings["SWIFT_OPTIMIZATION_LEVEL"] =
    config.name == "Debug" ? "-Onone" : "-O"
end

# ---------------------------------------------------------------------
# Step 2: ensure main.swift is in the target's Sources build phase
# ---------------------------------------------------------------------

# Find or create a PBXGroup for the bridge directory under the project root.
# Keep it simple: a dedicated top-level group at the project root.
bridge_group = project.main_group.find_subpath(BRIDGE_TARGET_NAME, true)
bridge_group.set_source_tree("<group>")
bridge_group.set_path(BRIDGE_TARGET_NAME)

main_swift_ref = bridge_group.files.find { |f| f.path == "main.swift" }
if main_swift_ref.nil?
  puts "[add] adding #{BRIDGE_TARGET_NAME}/main.swift to group"
  main_swift_ref = bridge_group.new_reference("main.swift")
else
  puts "[skip] main.swift already referenced"
end

# Add to Sources build phase if missing.
sources_phase = bridge_target.source_build_phase
already_in_sources = sources_phase.files_references.any? { |r| r == main_swift_ref }
if already_in_sources
  puts "[skip] main.swift already in #{BRIDGE_TARGET_NAME} Sources phase"
else
  puts "[add] adding main.swift to #{BRIDGE_TARGET_NAME} Sources phase"
  sources_phase.add_file_reference(main_swift_ref)
end

# ---------------------------------------------------------------------
# Step 3: make the app target depend on the bridge target
# ---------------------------------------------------------------------

app_target = project.native_targets.find { |t| t.name == APP_TARGET_NAME }
abort "App target #{APP_TARGET_NAME} not found" if app_target.nil?

already_depends = app_target.dependencies.any? do |dep|
  dep.target&.name == BRIDGE_TARGET_NAME
end
if already_depends
  puts "[skip] #{APP_TARGET_NAME} already depends on #{BRIDGE_TARGET_NAME}"
else
  puts "[add] adding #{BRIDGE_TARGET_NAME} to #{APP_TARGET_NAME} dependencies"
  app_target.add_dependency(bridge_target)
end

# ---------------------------------------------------------------------
# Step 4: Copy Files build phase that embeds the bridge binary in
#         AiyuTerm.app/Contents/Helpers/
# ---------------------------------------------------------------------

copy_phase = app_target.copy_files_build_phases.find { |p| p.name == COPY_FILES_PHASE_NAME }
if copy_phase.nil?
  puts "[add] creating Copy Files phase '#{COPY_FILES_PHASE_NAME}'"
  copy_phase = app_target.new_copy_files_build_phase(COPY_FILES_PHASE_NAME)
  copy_phase.symbol_dst_subfolder_spec = :wrapper
  copy_phase.dst_path = "Contents/Helpers"
else
  puts "[skip] Copy Files phase '#{COPY_FILES_PHASE_NAME}' already present"
  copy_phase.symbol_dst_subfolder_spec = :wrapper
  copy_phase.dst_path = "Contents/Helpers"
end

# Add the bridge target's product reference as a build file in the phase.
product_ref = bridge_target.product_reference
already_copied = copy_phase.files_references.any? { |r| r == product_ref }
if already_copied
  puts "[skip] bridge binary already in Copy Files phase"
else
  puts "[add] adding bridge binary to Copy Files phase"
  build_file = copy_phase.add_file_reference(product_ref)
  # Code-sign-on-copy flag is harmless with ad-hoc identity and makes
  # Gatekeeper happy on first launch.
  build_file.settings = { "ATTRIBUTES" => ["CodeSignOnCopy"] }
end

# ---------------------------------------------------------------------
# Step 5: save (or dry-run report)
# ---------------------------------------------------------------------

if check_only
  puts "--check: not writing project file"
  puts "project dirty? #{project.dirty?}"
else
  project.save
  puts "Saved #{PROJECT_PATH}"
end
