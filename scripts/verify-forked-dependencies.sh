#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export DEPENDENCY_FORKS_MANIFEST="${DEPENDENCY_FORKS_MANIFEST:-$ROOT_DIR/docs/dependency-forks.json}"
export DEPENDENCY_FORKS_PROJECT_YML="${DEPENDENCY_FORKS_PROJECT_YML:-$ROOT_DIR/project.yml}"
export DEPENDENCY_FORKS_PACKAGE_RESOLVED="${DEPENDENCY_FORKS_PACKAGE_RESOLVED:-$ROOT_DIR/Primo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved}"
export DEPENDENCY_FORKS_DOC="${DEPENDENCY_FORKS_DOC:-$ROOT_DIR/docs/DependencyForks.md}"
export DEPENDENCY_FORKS_ROOT="${DEPENDENCY_FORKS_ROOT:-$ROOT_DIR}"

ruby <<'RUBY'
require "json"
require "yaml"
require "digest"

manifest_path = ENV.fetch("DEPENDENCY_FORKS_MANIFEST")
project_path = ENV.fetch("DEPENDENCY_FORKS_PROJECT_YML")
resolved_path = ENV.fetch("DEPENDENCY_FORKS_PACKAGE_RESOLVED")
doc_path = ENV.fetch("DEPENDENCY_FORKS_DOC")
root_path = ENV.fetch("DEPENDENCY_FORKS_ROOT")

def fail_with(message)
  warn "Fork dependency guard failed: #{message}"
  exit 1
end

def read_json(path)
  JSON.parse(File.read(path))
rescue Errno::ENOENT
  fail_with("missing file #{path}")
rescue JSON::ParserError => error
  fail_with("invalid JSON in #{path}: #{error.message}")
end

def read_yaml(path)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
rescue Errno::ENOENT
  fail_with("missing file #{path}")
rescue Psych::Exception => error
  fail_with("invalid YAML in #{path}: #{error.message}")
end

manifest = read_json(manifest_path)
forks = manifest.fetch("forks") { fail_with("#{manifest_path} is missing forks") }
project = read_yaml(project_path)
project_packages = project.fetch("packages") { fail_with("#{project_path} is missing packages") }
resolved = read_json(resolved_path)
pins = resolved.fetch("pins") { fail_with("#{resolved_path} is missing pins") }
doc = File.read(doc_path)

errors = []

forks.each do |fork|
  package = fork.fetch("package")
  identity = fork.fetch("identity")
  fork_url = fork.fetch("forkURL")
  revision = fork.fetch("revision")
  upstream_url = fork.fetch("upstreamURL")
  reason_id = fork.fetch("reasonID")

  project_entry = project_packages[package]
  if project_entry.nil?
    errors << "project.yml is missing package #{package}"
  else
    actual_url = project_entry["url"]
    actual_revision = project_entry["revision"]
    errors << "project.yml #{package} url is #{actual_url.inspect}; expected #{fork_url.inspect}" unless actual_url == fork_url
    errors << "project.yml #{package} revision is #{actual_revision.inspect}; expected #{revision.inspect}" unless actual_revision == revision
  end

  resolved_entry = pins.find { |pin| pin["identity"] == identity }
  if resolved_entry.nil?
    errors << "Package.resolved is missing identity #{identity}"
  else
    actual_location = resolved_entry["location"]
    actual_revision = resolved_entry.dig("state", "revision")
    errors << "Package.resolved #{identity} location is #{actual_location.inspect}; expected #{fork_url.inspect}" unless actual_location == fork_url
    errors << "Package.resolved #{identity} revision is #{actual_revision.inspect}; expected #{revision.inspect}" unless actual_revision == revision
  end

  {
    "package #{package}" => package,
    "identity #{identity}" => identity,
    "fork revision #{revision}" => revision,
    "fork URL #{fork_url}" => fork_url,
    "upstream URL #{upstream_url}" => upstream_url,
    "reason ID #{reason_id}" => reason_id,
  }.each do |label, value|
    errors << "#{doc_path} does not mention #{label}" unless doc.include?(value)
  end

  next unless fork.key?("buildTimePatch")

  patch = fork.fetch("buildTimePatch")
  patch_id = patch.fetch("id")
  patch_script = patch.fetch("script")
  expected_sha256 = patch.fetch("sha256")
  patch_path = File.expand_path(patch_script, root_path)

  if !File.file?(patch_path)
    errors << "build-time patch #{patch_id} script is missing at #{patch_script}"
  else
    actual_sha256 = Digest::SHA256.file(patch_path).hexdigest
    errors << "build-time patch #{patch_id} sha256 is #{actual_sha256.inspect}; expected #{expected_sha256.inspect}" unless actual_sha256 == expected_sha256
  end

  {
    "build-time patch ID #{patch_id}" => patch_id,
    "build-time patch script #{patch_script}" => patch_script,
    "build-time patch sha256 #{expected_sha256}" => expected_sha256,
  }.each do |label, value|
    errors << "#{doc_path} does not mention #{label}" unless doc.include?(value)
  end
end

if errors.any?
  warn "Fork dependency guard found #{errors.length} issue(s):"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Fork dependency guard passed for #{forks.length} forked package(s)."
RUBY
