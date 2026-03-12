locals {
  supported_layers        = toset(keys(var.dataset_ids_by_layer))
  supported_trigger_modes = toset(["ON_DEMAND", "SCHEDULE", "ONE_TIME"])
  profile_scans_input     = coalesce(try(var.datascans.profile_scans, null), {})
  quality_scans_input     = coalesce(try(var.datascans.quality_scans, null), {})

  # Normalize enabled profile scans and resolve BQ resource URIs from layer/table when used.
  profile_scans = {
    for scan_id, scan in local.profile_scans_input :
    scan_id => {
      display_name        = coalesce(try(scan.display_name, null), scan_id)
      description         = try(scan.description, null)
      labels              = merge(var.labels, coalesce(try(scan.labels, null), {}))
      direct_resource_uri = try(scan.resource_uri, null)
      target_layer        = try(scan.layer, null)
      target_table_id     = try(scan.table_id, null)
      resource_uri = coalesce(
        try(scan.resource_uri, null),
        try(format("//bigquery.googleapis.com/projects/%s/datasets/%s/tables/%s", var.project_id, var.dataset_ids_by_layer[scan.layer], scan.table_id), null)
      )
      execution_field                      = try(scan.execution.field, null)
      trigger_mode                         = upper(coalesce(try(scan.execution.trigger_mode, null), "ON_DEMAND"))
      schedule_cron                        = try(scan.execution.schedule_cron, null)
      one_time_ttl_after_scan_completion   = try(scan.execution.one_time_ttl_after_scan_completion, null)
      catalog_publishing_enabled           = try(scan.catalog_publishing_enabled, null)
      row_filter                           = try(scan.row_filter, null)
      sampling_percent                     = try(scan.sampling_percent, null)
      include_fields                       = coalesce(try(scan.include_fields, null), [])
      exclude_fields                       = coalesce(try(scan.exclude_fields, null), [])
      post_scan_results_table_resource_uri = try(scan.post_scan_actions.bigquery_export_results_table, null)
    }
    if coalesce(try(scan.enabled, null), true)
  }

  # Normalize enabled quality scans and resolve BQ resource URIs from layer/table when used.
  quality_scans = {
    for scan_id, scan in local.quality_scans_input :
    scan_id => {
      display_name        = coalesce(try(scan.display_name, null), scan_id)
      description         = try(scan.description, null)
      labels              = merge(var.labels, coalesce(try(scan.labels, null), {}))
      direct_resource_uri = try(scan.resource_uri, null)
      target_layer        = try(scan.layer, null)
      target_table_id     = try(scan.table_id, null)
      resource_uri = coalesce(
        try(scan.resource_uri, null),
        try(format("//bigquery.googleapis.com/projects/%s/datasets/%s/tables/%s", var.project_id, var.dataset_ids_by_layer[scan.layer], scan.table_id), null)
      )
      execution_field                      = try(scan.execution.field, null)
      trigger_mode                         = upper(coalesce(try(scan.execution.trigger_mode, null), "ON_DEMAND"))
      schedule_cron                        = try(scan.execution.schedule_cron, null)
      one_time_ttl_after_scan_completion   = try(scan.execution.one_time_ttl_after_scan_completion, null)
      catalog_publishing_enabled           = try(scan.catalog_publishing_enabled, null)
      row_filter                           = try(scan.row_filter, null)
      sampling_percent                     = try(scan.sampling_percent, null)
      post_scan_results_table_resource_uri = try(scan.post_scan_actions.bigquery_export_results_table, null)
      rules = [
        for rule in coalesce(try(scan.rules, null), []) : {
          name                        = try(rule.name, null)
          description                 = try(rule.description, null)
          dimension                   = try(rule.dimension, null)
          column                      = try(rule.column, null)
          ignore_null                 = try(rule.ignore_null, null)
          suspended                   = try(rule.suspended, null)
          threshold                   = try(rule.threshold, null)
          non_null_expectation        = try(rule.non_null_expectation, null)
          range_expectation           = try(rule.range_expectation, null)
          regex_expectation           = try(rule.regex_expectation, null)
          row_condition_expectation   = try(rule.row_condition_expectation, null)
          set_expectation             = try(rule.set_expectation, null)
          sql_assertion               = try(rule.sql_assertion, null)
          statistic_range_expectation = try(rule.statistic_range_expectation, null)
          table_condition_expectation = try(rule.table_condition_expectation, null)
          uniqueness_expectation      = try(rule.uniqueness_expectation, null)
        }
      ]
    }
    if coalesce(try(scan.enabled, null), true)
  }
}

check "datascan_ids_are_valid" {
  assert {
    condition     = length(setintersection(toset(keys(local.profile_scans_input)), toset(keys(local.quality_scans_input)))) == 0
    error_message = "Dataplex profile_scans and quality_scans cannot reuse the same scan id."
  }
}

check "datascan_targets_and_execution_are_valid" {
  assert {
    condition = alltrue([
      for _, scan in merge(local.profile_scans, local.quality_scans) :
      (
        (
          scan.direct_resource_uri != null &&
          scan.target_layer == null &&
          scan.target_table_id == null
        ) ||
        (
          scan.direct_resource_uri == null &&
          scan.target_layer != null &&
          scan.target_table_id != null
        )
      )
    ])
    error_message = "Each enabled DataScan must use either resource_uri or (layer + table_id), but not both."
  }

  assert {
    condition = alltrue([
      for _, scan in merge(local.profile_scans, local.quality_scans) :
      scan.target_layer == null || contains(local.supported_layers, scan.target_layer)
    ])
    error_message = "DataScan layer must be one of: raw, bronze, silver, gold."
  }

  assert {
    condition = alltrue([
      for _, scan in merge(local.profile_scans, local.quality_scans) :
      scan.resource_uri != null
    ])
    error_message = "DataScan target resource URI could not be resolved. Check layer/table_id or resource_uri."
  }

  assert {
    condition = alltrue([
      for _, scan in merge(local.profile_scans, local.quality_scans) :
      contains(local.supported_trigger_modes, scan.trigger_mode)
    ])
    error_message = "DataScan execution.trigger_mode must be one of: ON_DEMAND, SCHEDULE, ONE_TIME."
  }

  assert {
    condition = alltrue([
      for _, scan in merge(local.profile_scans, local.quality_scans) :
      scan.trigger_mode != "SCHEDULE" || (scan.schedule_cron != null && trim(scan.schedule_cron, " ") != "")
    ])
    error_message = "DataScan execution.schedule_cron is required when trigger_mode = SCHEDULE."
  }
}

check "data_quality_rules_are_valid" {
  assert {
    condition = alltrue([
      for _, scan in local.quality_scans :
      length(scan.rules) > 0
    ])
    error_message = "Each enabled data quality scan must define at least one rule."
  }

  assert {
    condition = alltrue(flatten([
      for _, scan in local.quality_scans : [
        for rule in scan.rules :
        rule.dimension != null
      ]
    ]))
    error_message = "Each data quality rule must define dimension."
  }

  assert {
    condition = alltrue(flatten([
      for _, scan in local.quality_scans : [
        for rule in scan.rules :
        length(compact([
          rule.non_null_expectation == null ? null : "non_null_expectation",
          rule.range_expectation == null ? null : "range_expectation",
          rule.regex_expectation == null ? null : "regex_expectation",
          rule.row_condition_expectation == null ? null : "row_condition_expectation",
          rule.set_expectation == null ? null : "set_expectation",
          rule.sql_assertion == null ? null : "sql_assertion",
          rule.statistic_range_expectation == null ? null : "statistic_range_expectation",
          rule.table_condition_expectation == null ? null : "table_condition_expectation",
          rule.uniqueness_expectation == null ? null : "uniqueness_expectation",
        ])) == 1
      ]
    ]))
    error_message = "Each data quality rule must define exactly one expectation block."
  }
}

# Provision Dataplex data profile scans for selected BigQuery tables.
resource "google_dataplex_datascan" "profile" {
  for_each = local.profile_scans

  project = var.project_id

  location     = var.location
  data_scan_id = each.key
  display_name = each.value.display_name
  description  = each.value.description
  labels       = each.value.labels

  data {
    resource = each.value.resource_uri
  }

  execution_spec {
    field = each.value.execution_field

    trigger {
      dynamic "on_demand" {
        for_each = each.value.trigger_mode == "ON_DEMAND" ? [1] : []
        content {}
      }

      dynamic "schedule" {
        for_each = each.value.trigger_mode == "SCHEDULE" ? [1] : []
        content {
          cron = each.value.schedule_cron
        }
      }

      dynamic "one_time" {
        for_each = each.value.trigger_mode == "ONE_TIME" ? [1] : []
        content {
          ttl_after_scan_completion = each.value.one_time_ttl_after_scan_completion
        }
      }
    }
  }

  data_profile_spec {
    catalog_publishing_enabled = each.value.catalog_publishing_enabled
    row_filter                 = each.value.row_filter
    sampling_percent           = each.value.sampling_percent

    dynamic "include_fields" {
      for_each = length(each.value.include_fields) == 0 ? [] : [each.value.include_fields]
      content {
        field_names = include_fields.value
      }
    }

    dynamic "exclude_fields" {
      for_each = length(each.value.exclude_fields) == 0 ? [] : [each.value.exclude_fields]
      content {
        field_names = exclude_fields.value
      }
    }

    dynamic "post_scan_actions" {
      for_each = each.value.post_scan_results_table_resource_uri == null ? [] : [1]
      content {
        bigquery_export {
          results_table = each.value.post_scan_results_table_resource_uri
        }
      }
    }
  }
}

# Provision Dataplex data quality scans for selected BigQuery tables.
resource "google_dataplex_datascan" "quality" {
  for_each = local.quality_scans

  project = var.project_id

  location     = var.location
  data_scan_id = each.key
  display_name = each.value.display_name
  description  = each.value.description
  labels       = each.value.labels

  data {
    resource = each.value.resource_uri
  }

  execution_spec {
    field = each.value.execution_field

    trigger {
      dynamic "on_demand" {
        for_each = each.value.trigger_mode == "ON_DEMAND" ? [1] : []
        content {}
      }

      dynamic "schedule" {
        for_each = each.value.trigger_mode == "SCHEDULE" ? [1] : []
        content {
          cron = each.value.schedule_cron
        }
      }

      dynamic "one_time" {
        for_each = each.value.trigger_mode == "ONE_TIME" ? [1] : []
        content {
          ttl_after_scan_completion = each.value.one_time_ttl_after_scan_completion
        }
      }
    }
  }

  data_quality_spec {
    catalog_publishing_enabled = each.value.catalog_publishing_enabled
    row_filter                 = each.value.row_filter
    sampling_percent           = each.value.sampling_percent

    dynamic "post_scan_actions" {
      for_each = each.value.post_scan_results_table_resource_uri == null ? [] : [1]
      content {
        bigquery_export {
          results_table = each.value.post_scan_results_table_resource_uri
        }
      }
    }

    dynamic "rules" {
      for_each = each.value.rules
      iterator = rule
      content {
        name        = rule.value.name
        description = rule.value.description
        dimension   = rule.value.dimension
        column      = rule.value.column
        ignore_null = rule.value.ignore_null
        suspended   = rule.value.suspended
        threshold   = rule.value.threshold

        dynamic "non_null_expectation" {
          for_each = rule.value.non_null_expectation == null ? [] : [rule.value.non_null_expectation]
          content {}
        }

        dynamic "range_expectation" {
          for_each = rule.value.range_expectation == null ? [] : [rule.value.range_expectation]
          content {
            min_value          = try(range_expectation.value.min_value, null)
            max_value          = try(range_expectation.value.max_value, null)
            strict_min_enabled = try(range_expectation.value.strict_min_enabled, null)
            strict_max_enabled = try(range_expectation.value.strict_max_enabled, null)
          }
        }

        dynamic "regex_expectation" {
          for_each = rule.value.regex_expectation == null ? [] : [rule.value.regex_expectation]
          content {
            regex = regex_expectation.value.regex
          }
        }

        dynamic "row_condition_expectation" {
          for_each = rule.value.row_condition_expectation == null ? [] : [rule.value.row_condition_expectation]
          content {
            sql_expression = row_condition_expectation.value.sql_expression
          }
        }

        dynamic "set_expectation" {
          for_each = rule.value.set_expectation == null ? [] : [rule.value.set_expectation]
          content {
            values = set_expectation.value.values
          }
        }

        dynamic "sql_assertion" {
          for_each = rule.value.sql_assertion == null ? [] : [rule.value.sql_assertion]
          content {
            sql_statement = sql_assertion.value.sql_statement
          }
        }

        dynamic "statistic_range_expectation" {
          for_each = rule.value.statistic_range_expectation == null ? [] : [rule.value.statistic_range_expectation]
          content {
            statistic          = statistic_range_expectation.value.statistic
            min_value          = try(statistic_range_expectation.value.min_value, null)
            max_value          = try(statistic_range_expectation.value.max_value, null)
            strict_min_enabled = try(statistic_range_expectation.value.strict_min_enabled, null)
            strict_max_enabled = try(statistic_range_expectation.value.strict_max_enabled, null)
          }
        }

        dynamic "table_condition_expectation" {
          for_each = rule.value.table_condition_expectation == null ? [] : [rule.value.table_condition_expectation]
          content {
            sql_expression = table_condition_expectation.value.sql_expression
          }
        }

        dynamic "uniqueness_expectation" {
          for_each = rule.value.uniqueness_expectation == null ? [] : [rule.value.uniqueness_expectation]
          content {}
        }
      }
    }
  }
}
