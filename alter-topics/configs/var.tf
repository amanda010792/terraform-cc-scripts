variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_env_id" {
  description = "Confluent Cloud Environment ID"
  type = string
}

variable "schema_registry_id" {
  description = "Confluent Cloud Schema Registry ID"
  type = string
}
