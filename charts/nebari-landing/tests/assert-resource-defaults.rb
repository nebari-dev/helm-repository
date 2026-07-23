#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

EXPECTED_RESOURCES = {
  "frontend Deployment" => {
    kind: "Deployment",
    labels: { "app.kubernetes.io/component" => "frontend" },
    container: "frontend",
    resources: {
      "requests" => { "cpu" => "10m", "memory" => "32Mi" },
      "limits" => { "cpu" => "100m", "memory" => "64Mi" }
    }
  },
  "webapi Deployment" => {
    kind: "Deployment",
    labels: { "app.kubernetes.io/component" => "webapi" },
    container: "webapi",
    resources: {
      "requests" => { "cpu" => "25m", "memory" => "64Mi" },
      "limits" => { "cpu" => "200m", "memory" => "128Mi" }
    }
  },
  "redis master StatefulSet" => {
    kind: "StatefulSet",
    labels: {
      "app.kubernetes.io/name" => "redis",
      "app.kubernetes.io/component" => "master"
    },
    container: "redis",
    resources: {
      "requests" => { "cpu" => "50m", "memory" => "64Mi" },
      "limits" => { "cpu" => "200m", "memory" => "128Mi" }
    }
  }
}.freeze

def labels_match?(manifest, expected_labels)
  labels = manifest.dig("metadata", "labels") || {}
  expected_labels.all? { |key, value| labels[key] == value }
end

def pod_containers(manifest)
  manifest.dig("spec", "template", "spec", "containers") || []
end

manifests = YAML.load_stream(ARGF.read).compact.select { |doc| doc.is_a?(Hash) }
failures = []

EXPECTED_RESOURCES.each do |name, expected|
  manifest = manifests.find do |doc|
    doc["kind"] == expected[:kind] && labels_match?(doc, expected[:labels])
  end

  unless manifest
    failures << "Missing #{name}"
    next
  end

  container = pod_containers(manifest).find { |entry| entry["name"] == expected[:container] }
  unless container
    failures << "Missing #{expected[:container]} container in #{name}"
    next
  end

  next if container["resources"] == expected[:resources]

  failures << "#{name} resources were #{container['resources'].inspect}, expected #{expected[:resources].inspect}"
end

abort failures.join("\n") unless failures.empty?

puts "Rendered resource defaults match expected chart values."
