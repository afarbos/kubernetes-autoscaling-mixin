local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-hpa.json':

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.hpa,
        defaultVariables.metricName,
        defaultVariables.metricTargetType,
      ];

      local queries = {
        desiredReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_desired_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        currentReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_status_current_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        minReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_min_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        maxReplicas: |||
          round(
            sum(
              kube_horizontalpodautoscaler_spec_max_replicas{
                cluster="$cluster",
                namespace=~"$namespace",
                horizontalpodautoscaler="$hpa"
              }
            )
          )
        |||,

        metricTargets: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,

        usageThreshold: |||
          sum(
            kube_horizontalpodautoscaler_spec_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name",
              metric_target_type=~"$metric_target_type"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,

        utilization: |||
          sum(
            kube_horizontalpodautoscaler_status_target_metric{
              cluster="$cluster",
              namespace=~"$namespace",
              horizontalpodautoscaler="$hpa",
              metric_name=~"$metric_name",
              metric_target_type=~"$metric_target_type"
            }
          ) by (job, namespace, horizontalpodautoscaler, metric_name, metric_target_type)
        |||,
      };

      local panels = {
        desiredReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Desired Replicas',
            'short',
            queries.desiredReplicas,
            description='The desired number of replicas for the HPA.',
          ),

        currentReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Current Replicas',
            'short',
            queries.currentReplicas,
            description='The current number of replicas for the HPA.',
          ),

        minReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Min Replicas',
            'short',
            queries.minReplicas,
            description='The minimum number of replicas configured for the HPA.',
          ),

        maxReplicasStat:
          mixinUtils.dashboards.statPanel(
            'Max Replicas',
            'short',
            queries.maxReplicas,
            description='The maximum number of replicas configured for the HPA.',
          ),

        usageAndThresholdTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Usage & Threshold',
            'short',
            [
              {
                expr: queries.utilization,
                legend: '{{ metric_target_type }} / {{ metric_name }}',
              },
              {
                expr: queries.usageThreshold,
                legend: 'Threshold / {{ metric_name }}',
              },
            ],
            calcs=['lastNotNull', 'mean', 'max'],
            description='The current utilization and configured threshold for the HPA metric.',
          ),

        replicasTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Replicas',
            'short',
            [
              {
                expr: queries.desiredReplicas,
                legend: 'Desired Replicas',
              },
              {
                expr: queries.currentReplicas,
                legend: 'Current Replicas',
              },
              {
                expr: queries.minReplicas,
                legend: 'Min Replicas',
              },
              {
                expr: queries.maxReplicas,
                legend: 'Max Replicas',
              },
            ],
            calcs=['lastNotNull', 'mean', 'max'],
            description='The desired, current, minimum, and maximum replicas for the HPA over time.',
          ),

        metricTargetsTable:
          mixinUtils.dashboards.tablePanel(
            'Metric Targets',
            'short',
            queries.metricTargets,
            description='Configured metric targets for the HPA.',
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [
            panels.desiredReplicasStat,
            panels.currentReplicasStat,
            panels.minReplicasStat,
            panels.maxReplicasStat,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        [
          row.new('Metric Targets') +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.metricTargetsTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(6) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
          row.new('Metrics') +
          row.gridPos.withX(0) +
          row.gridPos.withY(14) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.usageAndThresholdTimeSeries +
          g.panel.timeSeries.gridPos.withX(0) +
          g.panel.timeSeries.gridPos.withY(15) +
          g.panel.timeSeries.gridPos.withW(24) +
          g.panel.timeSeries.gridPos.withH(6),
          panels.replicasTimeSeries +
          g.panel.timeSeries.gridPos.withX(0) +
          g.panel.timeSeries.gridPos.withY(21) +
          g.panel.timeSeries.gridPos.withW(24) +
          g.panel.timeSeries.gridPos.withH(6),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / HPA',
      ) +
      dashboard.withDescription('A dashboard that monitors Horizontal Pod Autoscalers. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
      dashboard.withUid($._config.hpaDashboardUid) +
      dashboard.withTags($._config.tags + ['hpa']) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('Kubernetes / Autoscaling', $._config, dropdown=true)
      ) +
      dashboard.withPanels(rows),
  },
}
