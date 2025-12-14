local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    job: 'job=~"$job"',
    namespace: 'namespace=~"$namespace"',
    pdb: 'poddisruptionbudget=~"$pdb"',

    base: '%(cluster)s, %(job)s, %(namespace)s' % this,
    withPdb: '%(base)s, %(pdb)s' % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new(
        config.clusterLabel,
        'label_values(kube_pod_info{%(kubeStateMetricsSelector)s}, cluster)' % config,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    job:
      query.new(
        'job',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s}, job)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    namespace:
      query.new(
        'namespace',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s, %(job)s}, namespace)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort(1) +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    pdb:
      query.new(
        'pdb',
        'label_values(kube_poddisruptionbudget_status_current_healthy{%(cluster)s, %(namespace)s}, poddisruptionbudget)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Pod Disruption Budget') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    hpa:
      query.new(
        'hpa',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(namespace)s}, horizontalpodautoscaler)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('HPA') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    metricName:
      query.new(
        'metric_name',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(namespace)s, horizontalpodautoscaler=\"$hpa\"}, metric_name)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric Name') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    metricTargetType:
      query.new(
        'metric_target_type',
        'label_values(kube_horizontalpodautoscaler_spec_target_metric{%(cluster)s, %(namespace)s, horizontalpodautoscaler=\"$hpa\", metric_name=~\"$metric_name\"}, metric_target_type)' % defaultFilters,
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Metric Target Type') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
