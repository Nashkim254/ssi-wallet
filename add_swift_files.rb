#!/usr/bin/env ruby

# Script to add Swift files to Xcode project using xcodeproj gem
# This is the proper way to modify Xcode project files

require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Runner group (where our Swift files live)
runner_group = project.main_group.find_subpath('Runner', true)

# Files to add
swift_files = [
  'SsiApi.swift',
  'SprucekitSsiApiImpl.swift'
]

swift_files.each do |filename|
  file_path = "ios/Runner/#{filename}"

  # Check if file already exists in project
  existing_file = runner_group.files.find { |f| f.path == filename }

  if existing_file
    puts "✓ #{filename} already in project"
  else
    # Add file reference
    file_ref = runner_group.new_file(filename)

    # Add to build phase
    target.source_build_phase.add_file_reference(file_ref)

    puts "✓ Added #{filename} to project"
  end
end

# Save the project
project.save

puts "\n✅ Xcode project updated successfully!"
