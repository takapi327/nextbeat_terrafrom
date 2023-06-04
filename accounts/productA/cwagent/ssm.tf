resource "aws_ssm_parameter" "cloudwatch_agent_prometheus_config" {
  name  = "cloudwatchAgentPrometheusConfig"
  type  = "String"
  value = file("./prometheus_config.txt")
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name = "cloudwatchAgentConfig"
  type = "String"
  value = jsonencode({
    logs : {
      metrics_collected : {
        prometheus : {
          prometheus_config_path : "env:PROMETHEUS_CONFIG_CONTENT",
          ecs_service_discovery : {
            sd_frequency : "1m",
            sd_result_file : "/tmp/cwagent_ecs_auto_sd.yaml",
            docker_label : {},
            task_definition_list : [
              {
                sd_job_name : "ecs-jvm",
                sd_metrics_ports : "9090",
                sd_task_definition_arn_pattern : ".*:task-definition/.*jvm-microservice-server.*:[0-9]+",
                sd_metrics_path : "/stats/prometheus"
              }
            ]
          },
          emf_processor : {
            metric_namespace : "CWAgent",
            metric_declaration : [
              {
                source_labels : ["container_name"],
                label_matcher : "^${aws_ecr_repository.jvm_server.name}$",
                dimensions : [["ClusterName", "TaskDefinitionFamily"]],
                metric_selectors : [
                  "^jvm_classes_loaded",
                  "^jvm_threads_current",
                  "^jvm_threads_daemon",
                  "^java_lang_operatingsystem_totalswapspacesize",
                  "^java_lang_operatingsystem_systemcpuload",
                  "^java_lang_operatingsystem_processcpuload",
                  "^java_lang_operatingsystem_freeswapspacesize",
                  "^java_lang_operatingsystem_totalphysicalmemorysize",
                  "^java_lang_operatingsystem_freephysicalmemorysize",
                  "^java_lang_operatingsystem_openfiledescriptorcount",
                  "^java_lang_operatingsystem_availableprocessors",
                  "^jvm_memory_pool_bytes_committed$",
                  "^jvm_memory_pool_bytes_init$",
                  "^jvm_memory_pool_bytes_max$",
                  "^jvm_memory_pool_bytes_used$",
                ]
              },
              {
                source_labels : ["container_name"],
                label_matcher : "^${aws_ecr_repository.jvm_server.name}$",
                dimensions : [["ClusterName", "TaskDefinitionFamily", "area"]],
                metric_selectors : [
                  "^jvm_memory_bytes_used"
                ]
              },
              {
                source_labels : ["container_name"],
                label_matcher : "^${aws_ecr_repository.jvm_server.name}$",
                dimensions : [["ClusterName", "TaskDefinitionFamily", "pool"]],
                metric_selectors : [
                  "^jvm_memory_pool_bytes_used"
                ]
              }
            ]
          }
        }
      },
      force_flush_interval : 5
    }
  })
}
