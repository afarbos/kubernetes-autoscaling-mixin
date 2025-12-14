local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbOverride = tbStandardOptions.override;
local tbFieldConfig = tablePanel.fieldConfig;

// Timeseries
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsOverride = tsStandardOptions.override;

{
  grafanaDashboards+:: {
    'kubernetes-autoscaling-mixin-pdb.json':

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.pdbJob,
        defaultVariables.pdbNamespace,
        defaultVariables.pdb,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        disruptionsAllowed: |||
          round(
            sum(
              kube_poddisruptionbudget_status_pod_disruptions_allowed{
                %(withPdb)s
              }
            )
          )
        ||| % defaultFilters,

        desiredHealthy: |||
          round(
            sum(
              kube_poddisruptionbudget_status_desired_healthy{
                %(withPdb)s
              }
            )
          )
        ||| % defaultFilters,

        currentlyHealthy: |||
          round(
            sum(
              kube_poddisruptionbudget_status_current_healthy{
                %(withPdb)s
              }
            )
          )
        ||| % defaultFilters,

        expectedPods: |||
          round(
            sum(
              kube_poddisruptionbudget_status_expected_pods{
                %(withPdb)s
              }
            )
          )
        ||| % defaultFilters,

        disruptionsAllowedNamespace: |||
          round(
            sum(
              kube_poddisruptionbudget_status_pod_disruptions_allowed{
                %(base)s
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        ||| % defaultFilters,

        desiredHealthyNamespace: |||
          round(
            sum(
              kube_poddisruptionbudget_status_desired_healthy{
                %(base)s
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        ||| % defaultFilters,

        currentlyHealthyNamespace: |||
          round(
            sum(
              kube_poddisruptionbudget_status_current_healthy{
                %(base)s
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        ||| % defaultFilters,

        expectedPodsNamespace: |||
          round(
            sum(
              kube_poddisruptionbudget_status_expected_pods{
                %(base)s
              }
            ) by (job, namespace, poddisruptionbudget)
          )
        ||| % defaultFilters,
      };

      local panels = {
        disruptionsAllowedStat:
          mixinUtils.dashboards.statPanel(
            'Disruptions Allowed',
            'short',
            queries.disruptionsAllowed,
            description='The number of pod disruptions allowed for the selected PDB.',
          ),

        desiredHealthyStat:
          mixinUtils.dashboards.statPanel(
            'Desired Healthy',
            'short',
            queries.desiredHealthy,
            description='The desired number of healthy pods for the selected PDB.',
          ),

        currentlyHealthyStat:
          mixinUtils.dashboards.statPanel(
            'Currently Healthy',
            'short',
            queries.currentlyHealthy,
            description='The current number of healthy pods for the selected PDB.',
          ),

        expectedPodsStat:
          mixinUtils.dashboards.statPanel(
            'Expected Pods',
            'short',
            queries.expectedPods,
            description='The expected number of pods for the selected PDB.',
          ),

        namespaceSummaryTable:
          mixinUtils.dashboards.tablePanel(
            'Summary',
            'short',
            [
              {
                expr: queries.disruptionsAllowedNamespace,
                legend: 'Disruptions Allowed',
              },
              {
                expr: queries.desiredHealthyNamespace,
                legend: 'Desired Healthy',
              },
              {
                expr: queries.currentlyHealthyNamespace,
                legend: 'Currently Healthy',
              },
              {
                expr: queries.expectedPodsNamespace,
                legend: 'Expected Pods',
              },
            ],
            description='Summary of all PDBs in the selected namespace.',
            sortBy={ name: 'Pod Disruption Budget', desc: false },
            transformations=[
              tbQueryOptions.transformation.withId('merge'),
              tbQueryOptions.transformation.withId('organize') +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    poddisruptionbudget: 'Pod Disruption Budget',
                    namespace: 'Namespace',
                    'Value #A': 'Disruptions Allowed',
                    'Value #B': 'Desired Healthy',
                    'Value #C': 'Currently Healthy',
                    'Value #D': 'Expected Pods',
                  },
                  indexByName: {
                    namespace: 0,
                    poddisruptionbudget: 1,
                    'Value #A': 2,
                    'Value #B': 3,
                    'Value #C': 4,
                    'Value #D': 5,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('Disruptions Allowed') +
              tbOverride.byName.withPropertiesFromOptions(
                tbFieldConfig.defaults.custom.withCellOptions(
                  { type: 'color-text' }
                ) +
                tbStandardOptions.thresholds.withMode('absolute') +
                tbStandardOptions.thresholds.withSteps([
                  tbStandardOptions.threshold.step.withValue(0) +
                  tbStandardOptions.threshold.step.withColor('red'),
                  tbStandardOptions.threshold.step.withValue(0.1) +
                  tbStandardOptions.threshold.step.withColor('green'),
                ])
              ),
            ],
          ),

        statusTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Status',
            'short',
            [
              {
                expr: queries.disruptionsAllowed,
                legend: 'Disruptions Allowed',
              },
              {
                expr: queries.desiredHealthy,
                legend: 'Desired Healthy',
              },
              {
                expr: queries.currentlyHealthy,
                legend: 'Currently Healthy',
              },
              {
                expr: queries.expectedPods,
                legend: 'Expected Pods',
              },
            ],
            description='Status metrics for the selected PDB over time.',
            fillOpacity=0,
            overrides=[
              tsOverride.byName.new('Currently Healthy') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('yellow')
              ),
              tsOverride.byName.new('Disruptions Allowed') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('red')
              ),
              tsOverride.byName.new('Desired Healthy') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('green')
              ),
              tsOverride.byName.new('Expected Pods') +
              tsOverride.byName.withPropertiesFromOptions(
                tsStandardOptions.color.withMode('fixed') +
                tsStandardOptions.color.withFixedColor('blue')
              ),
            ],
          ),
      };

      local rows =
        [
          row.new('$namespace Namespace Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.namespaceSummaryTable +
          row.gridPos.withX(0) +
          row.gridPos.withY(1) +
          row.gridPos.withW(24) +
          row.gridPos.withH(10),
          row.new('$poddisruptionbudget') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withRepeat('poddisruptionbudget'),
        ] +
        grid.makeGrid(
          [
            panels.disruptionsAllowedStat,
            panels.desiredHealthyStat,
            panels.currentlyHealthyStat,
            panels.expectedPodsStat,
          ],
          panelWidth=6,
          panelHeight=4,
          startY=12
        ) +
        [
          panels.statusTimeSeries +
          row.gridPos.withX(0) +
          row.gridPos.withY(16) +
          row.gridPos.withW(24) +
          row.gridPos.withH(10),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Kubernetes / Autoscaling / Pod Disruption Budget',
      ) +
      dashboard.withDescription('A dashboard that monitors Kubernetes and focuses on giving a overview for pod disruption budgets. %s' % mixinUtils.dashboards.dashboardDescriptionLink('kubernetes-autoscaling-mixin', 'https://github.com/adinhodovic/kubernetes-autoscaling-mixin')) +
      dashboard.withUid($._config.pdbDashboardUid) +
      dashboard.withTags($._config.tags + ['kubernetes-core']) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('Kubernetes / Autoscaling', $._config, dropdown=true)
      ) +
      dashboard.withPanels(rows) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
