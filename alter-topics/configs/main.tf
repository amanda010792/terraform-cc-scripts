terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.46.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# use environment designated
data "confluent_environment" "topic_test_env" {
  id = var.confluent_cloud_env_id
}

# spin up kafka cluster called "basic" in topic_test_env (created above)
resource "confluent_kafka_cluster" "basic" {
  display_name = "topic_test_basic"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  basic {}

  environment {
    id = data.confluent_environment.topic_test_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}


data "confluent_schema_registry_cluster" "schema_registry_cluster" {
  id = var.schema_registry_id
  environment {
    id = data.confluent_environment.topic_test_env.id
  }
}

# create a service account called topic manager 
resource "confluent_service_account" "topic-test-topic-manager" {
  display_name = local.topic-test-topic-manager
  description  = "Service account to manage Kafka cluster topics"
}

# create a role binding for topic manager service account (created above) that has cloud cluster admin access to basic cluster (created above)
resource "confluent_role_binding" "topic-test-topic-manager-role" {
  principal   = "User:${confluent_service_account.topic-test-topic-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

# create an api key for the topic manager service account (created above) 
resource "confluent_api_key" "topic-test-topic-manager-kafka-api-key" {
  display_name = "topic-test-topic-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'topic-test-topic-manager' service account"
  owner {
    id          = confluent_service_account.topic-test-topic-manager.id
    api_version = confluent_service_account.topic-test-topic-manager.api_version
    kind        = confluent_service_account.topic-test-topic-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = data.confluent_environment.topic_test_env.id
    }
  }

  depends_on = [
    confluent_role_binding.topic-test-topic-manager-role
  ]
}

# create a topic called orders using the api key (created above)
resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name         = "orders"
  partitions_count   = 4
  rest_endpoint      = confluent_kafka_cluster.basic.rest_endpoint
  # https://docs.confluent.io/cloud/current/clusters/broker-config.html#custom-topic-settings-for-all-cluster-types-supported-by-kafka-rest-api-and-terraform-provider
  config = {
    "cleanup.policy"                      = "delete"
    "delete.retention.ms"                 = "86400000"
    "max.compaction.lag.ms"               = "9223372036854775807"
    "max.message.bytes"                   = "2097164"
    "message.timestamp.difference.max.ms" = "9223372036854775807"
    "message.timestamp.type"              = "CreateTime"
    "min.compaction.lag.ms"               = "0"
    "min.insync.replicas"                 = "2"
    "retention.bytes"                     = "-1"
    "retention.ms"                        = "604800000"
    "segment.bytes"                       = "104857600"
    "segment.ms"                          = "604800000"
  }
  credentials {
    key    = confluent_api_key.topic-test-topic-manager-kafka-api-key.id
    secret = confluent_api_key.topic-test-topic-manager-kafka-api-key.secret
  }
}
