#!/usr/bin/env python3
"""
Script to add Swift files to Xcode project programmatically.
This modifies the project.pbxproj file to include the new Swift files.
"""

import re
import uuid
import sys

def generate_uuid():
    """Generate a unique 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

def add_swift_files_to_project(pbxproj_path, swift_files):
    """
    Add Swift files to Xcode project.pbxproj file.

    Args:
        pbxproj_path: Path to the project.pbxproj file
        swift_files: List of (filename, filepath) tuples
    """

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Filter out files that are already added
    files_to_add = []
    for filename, filepath in swift_files:
        if filename in content:
            print(f"✓ {filename} already in project")
        else:
            files_to_add.append((filename, filepath))

    if not files_to_add:
        print("All files are already in the project")
        return

    swift_files = files_to_add
    print(f"Adding {len(swift_files)} Swift files to Xcode project...")

    # Generate UUIDs for each file (we need 2 per file: fileRef and buildFile)
    file_data = []
    for filename, filepath in swift_files:
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()
        file_data.append({
            'filename': filename,
            'filepath': filepath,
            'file_ref_uuid': file_ref_uuid,
            'build_file_uuid': build_file_uuid
        })

    # 1. Add PBXBuildFile entries
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_entries = []
    for data in file_data:
        entry = f"\t\t{data['build_file_uuid']} /* {data['filename']} in Sources */ = {{isa = PBXBuildFile; fileRef = {data['file_ref_uuid']} /* {data['filename']} */; }};"
        build_file_entries.append(entry)

    # Find the end of PBXBuildFile section and add before it
    pbx_build_file_end = content.find("/* End PBXBuildFile section */")
    if pbx_build_file_end == -1:
        print("Error: Could not find PBXBuildFile section")
        return

    # Insert build file entries
    for entry in build_file_entries:
        content = content[:pbx_build_file_end] + entry + "\n" + content[pbx_build_file_end:]
        pbx_build_file_end += len(entry) + 1

    # 2. Add PBXFileReference entries
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_entries = []
    for data in file_data:
        entry = f"\t\t{data['file_ref_uuid']} /* {data['filename']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {data['filename']}; sourceTree = \"<group>\"; }};"
        file_ref_entries.append(entry)

    pbx_file_ref_end = content.find("/* End PBXFileReference section */")
    if pbx_file_ref_end == -1:
        print("Error: Could not find PBXFileReference section")
        return

    # Insert file reference entries
    for entry in file_ref_entries:
        content = content[:pbx_file_ref_end] + entry + "\n" + content[pbx_file_ref_end:]
        pbx_file_ref_end += len(entry) + 1

    # 3. Add to PBXGroup (Runner group)
    # Find the Runner group children array
    runner_group_pattern = r'(/\* Runner \*/\s*=\s*\{[^}]*?children\s*=\s*\([^)]*?)(\);)'

    match = re.search(runner_group_pattern, content, re.DOTALL)
    if not match:
        print("Error: Could not find Runner group")
        return

    # Add file references to the children array
    children_entries = []
    for data in file_data:
        entry = f"\n\t\t\t\t{data['file_ref_uuid']} /* {data['filename']} */,"
        children_entries.append(entry)

    # Insert before the closing );
    insert_pos = match.end(1)
    for entry in children_entries:
        content = content[:insert_pos] + entry + content[insert_pos:]
        insert_pos += len(entry)

    # 4. Add to PBXSourcesBuildPhase
    # Find the Sources build phase
    sources_phase_pattern = r'(/\* Sources \*/\s*=\s*\{[^}]*?files\s*=\s*\([^)]*?)(\);)'

    match = re.search(sources_phase_pattern, content, re.DOTALL)
    if not match:
        print("Error: Could not find Sources build phase")
        return

    # Add build files to the files array
    source_entries = []
    for data in file_data:
        entry = f"\n\t\t\t\t{data['build_file_uuid']} /* {data['filename']} in Sources */,"
        source_entries.append(entry)

    # Insert before the closing );
    insert_pos = match.end(1)
    for entry in source_entries:
        content = content[:insert_pos] + entry + content[insert_pos:]
        insert_pos += len(entry)

    # Write back to file
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print(f"✓ Successfully added {len(swift_files)} Swift files to Xcode project")
    for filename, _ in swift_files:
        print(f"  • {filename}")

if __name__ == "__main__":
    pbxproj_path = "ios/Runner.xcodeproj/project.pbxproj"

    swift_files = [
        ("SsiApi.swift", "Runner/SsiApi.swift"),
        ("EudiSsiApiImpl.swift", "Runner/EudiSsiApiImpl.swift"),
        ("EudiWalletCore.swift", "Runner/EudiWalletCore.swift"),
        ("SprucekitSsiApiImpl.swift", "Runner/SprucekitSsiApiImpl.swift"),
    ]

    try:
        add_swift_files_to_project(pbxproj_path, swift_files)
        print("\n✅ Xcode project updated successfully!")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
