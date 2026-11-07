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
  "health-prober Deployment" => {
    kind: "Deployment",
    labels: { "app.kubernetes.io/component" => "health-prober" },
    container: "health-prober",
    resources: {
      "requests" => { "cpu" => "10m", "memory" => "32Mi" },
      "limits" => { "cpu" => "100m", "memory" => "64Mi" }
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

# NetworkPolicies are opt-in. EXPECT_NETWORK_POLICIES lists the components
# whose policy the rendered manifests must contain (comma-separated: webapi,
# health-prober); every other policy must be absent. Empty means the default
# render, which ships no NetworkPolicy.
EXPECTED_POLICIES = ENV.fetch("EXPECT_NETWORK_POLICIES", "").split(",").map(&:strip).reject(&:empty?).freeze

EXPECTED_WEBAPI_EGRESS_PORTS = [53, 6379, 8080, 8443, 8081].freeze
EXPECTED_HEALTH_CHECK_PORTS = [80, 8080].freeze
DENIED_SAME_NAMESPACE_PORTS = [2379, 2380, 3306, 5432, 6379, 6443, 10250, 10255].freeze
PROTECTED_HEALTH_NAMESPACES = %w[
  kube-system kube-public kube-node-lease keycloak argocd cert-manager
  envoy-gateway-system metallb-system database databases db redis postgres
  postgresql mysql mariadb mongodb mongo vault
].freeze

def labels_match?(manifest, expected_labels)
  labels = manifest.dig("metadata", "labels") || {}
  expected_labels.all? { |key, value| labels[key] == value }
end

def pod_containers(manifest)
  manifest.dig("spec", "template", "spec", "containers") || []
end

def webapi_egress_policy(manifests)
  egress_policy_for(manifests, "webapi")
end

def health_prober_policy(manifests)
  egress_policy_for(manifests, "health-prober")
end

def egress_policy_for(manifests, component)
  manifests.find do |doc|
    doc["kind"] == "NetworkPolicy" &&
      labels_match?(doc, { "app.kubernetes.io/component" => component }) &&
      Array(doc.dig("spec", "policyTypes")).include?("Egress")
  end
end

def egress_ports(policy)
  Array(policy.dig("spec", "egress")).flat_map do |rule|
    Array(rule["ports"]).map { |entry| entry["port"] }
  end
end

def empty_pod_selector?(selector)
  selector.nil? || selector == {} || selector == { "matchLabels" => {} }
end

def hardcodes_default_api_server_cidr?(policy)
  Array(policy.dig("spec", "egress")).any? do |rule|
    Array(rule["to"]).any? do |target|
      target.dig("ipBlock", "cidr") == "10.96.0.1/32"
    end
  end
end

def keycloak_allow_is_namespace_wide?(policy)
  Array(policy.dig("spec", "egress")).any? do |rule|
    Array(rule["to"]).any? do |target|
      target.dig("namespaceSelector", "matchLabels", "kubernetes.io/metadata.name") == "keycloak" &&
        empty_pod_selector?(target["podSelector"])
    end
  end
end

def same_namespace_wildcard_ports(policy)
  Array(policy.dig("spec", "egress")).flat_map do |rule|
    wildcard_target = Array(rule["to"]).any? do |target|
      target["namespaceSelector"].nil? &&
        target["ipBlock"].nil? &&
        empty_pod_selector?(target["podSelector"])
    end
    wildcard_target ? Array(rule["ports"]).map { |entry| entry["port"] } : []
  end
end

def health_check_namespace_selector?(selector)
  Array(selector && selector["matchExpressions"]).any? do |expression|
    expression["key"] == "kubernetes.io/metadata.name" &&
      expression["operator"] == "NotIn" &&
      (PROTECTED_HEALTH_NAMESPACES - Array(expression["values"])).empty?
  end
end

def health_check_ports(policy)
  Array(policy.dig("spec", "egress")).flat_map do |rule|
    health_target = Array(rule["to"]).any? do |target|
      health_check_namespace_selector?(target["namespaceSelector"]) &&
        empty_pod_selector?(target["podSelector"])
    end
    health_target ? Array(rule["ports"]).map { |entry| entry["port"] } : []
  end
end

def has_same_namespace_health_allow?(policy)
  (EXPECTED_HEALTH_CHECK_PORTS - health_check_ports(policy)).empty?
end

def has_denied_same_namespace_ports?(policy)
  !(DENIED_SAME_NAMESPACE_PORTS & health_check_ports(policy)).empty?
end

def has_release_namespace_only_health_allow?(policy)
  (EXPECTED_HEALTH_CHECK_PORTS - same_namespace_wildcard_ports(policy)).empty?
end

def has_api_server_allow?(policy, cidr)
  Array(policy.dig("spec", "egress")).any? do |rule|
    Array(rule["to"]).any? do |target|
      target.dig("ipBlock", "cidr") == cidr
    end && Array(rule["ports"]).any? { |entry| entry["protocol"] == "TCP" && entry["port"] == 443 }
  end
end

def has_component_allow?(policy, direction, component, port)
  Array(policy.dig("spec", direction)).any? do |rule|
    Array(rule[direction == "egress" ? "to" : "from"]).any? do |target|
      target.dig("podSelector", "matchLabels", "app.kubernetes.io/component") == component
    end && Array(rule["ports"]).any? { |entry| entry["protocol"] == "TCP" && entry["port"] == port }
  end
end

def has_sensitive_dependency_egress?(policy)
  Array(policy.dig("spec", "egress")).any? do |rule|
    Array(rule["to"]).any? do |target|
      target.dig("podSelector", "matchLabels", "app.kubernetes.io/name") == "redis" ||
        target.dig("namespaceSelector", "matchLabels", "kubernetes.io/metadata.name") == "keycloak" ||
        target.key?("ipBlock")
    end
  end
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

webapi_policy = webapi_egress_policy(manifests)
if !EXPECTED_POLICIES.include?("webapi")
  failures << "webapi egress NetworkPolicy rendered but was not expected (it must be opt-in)" if webapi_policy
elsif webapi_policy.nil?
  failures << "Missing webapi egress NetworkPolicy"
else
  if hardcodes_default_api_server_cidr?(webapi_policy)
    failures << "webapi egress NetworkPolicy hard-codes the Kubernetes API ClusterIP"
  end

  if keycloak_allow_is_namespace_wide?(webapi_policy)
    failures << "webapi egress NetworkPolicy allows the whole Keycloak namespace"
  end

  if has_same_namespace_health_allow?(webapi_policy)
    failures << "webapi egress NetworkPolicy enables health-check egress by default"
  end

  if has_denied_same_namespace_ports?(webapi_policy)
    failures << "webapi egress NetworkPolicy allows denied same-namespace infrastructure ports"
  end

  if has_release_namespace_only_health_allow?(webapi_policy)
    failures << "webapi egress NetworkPolicy scopes health checks only to the release namespace"
  end

  unless has_component_allow?(webapi_policy, "egress", "health-prober", 8081)
    failures << "webapi egress NetworkPolicy does not route health probes through the health-prober"
  end

  expected_ports = EXPECTED_WEBAPI_EGRESS_PORTS.dup
  expected_ports << 443 << 6443 if ENV["EXPECTED_WEBAPI_API_CIDR"]
  missing_ports = expected_ports - egress_ports(webapi_policy)
  unless missing_ports.empty?
    failures << "webapi egress NetworkPolicy is missing expected ports #{missing_ports.inspect}"
  end

  expected_api_cidr = ENV["EXPECTED_WEBAPI_API_CIDR"]
  if expected_api_cidr && !has_api_server_allow?(webapi_policy, expected_api_cidr)
    failures << "webapi egress NetworkPolicy is missing Kubernetes API allow for #{expected_api_cidr}"
  end
end

health_policy = health_prober_policy(manifests)
if !EXPECTED_POLICIES.include?("health-prober")
  failures << "health-prober NetworkPolicy rendered but was not expected (it must be opt-in)" if health_policy
elsif health_policy.nil?
  failures << "Missing health-prober NetworkPolicy"
else
  if has_sensitive_dependency_egress?(health_policy)
    failures << "health-prober NetworkPolicy allows sensitive webapi dependency egress"
  end

  unless has_component_allow?(health_policy, "ingress", "webapi", 8081)
    failures << "health-prober NetworkPolicy does not restrict ingress to the webapi"
  end

  unless has_same_namespace_health_allow?(health_policy)
    failures << "health-prober NetworkPolicy is missing constrained health-check egress"
  end

  if has_denied_same_namespace_ports?(health_policy)
    failures << "health-prober NetworkPolicy allows denied health-check infrastructure ports"
  end

  if has_release_namespace_only_health_allow?(health_policy)
    failures << "health-prober NetworkPolicy scopes health checks only to the release namespace"
  end
end

abort failures.join("\n") unless failures.empty?

puts "Rendered resource defaults match expected chart values."
