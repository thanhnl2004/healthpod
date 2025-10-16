/// BP combined visualisation widget.
//
// Time-stamp: <Thursday 2025-06-26 17:00:52 +1000 Graham Williams>
//
/// Copyright (C) 2025, Software Innovation Institute, ANU
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://www.gnu.org/licenses/gpl-3.0.en.html
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
///
/// Authors: Ashley Tang

library;

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:healthpod/constants/blood_pressure_survey.dart';
import 'package:healthpod/features/survey/data.dart';
import 'package:healthpod/features/visualise/stat_item.dart';
import 'package:healthpod/utils/get_month_abbrev.dart';
import 'package:healthpod/utils/parse_numeric_input.dart';
import 'package:healthpod/utils/url_launcher_util.dart';

import 'dart:convert';
import 'package:solidpod/solidpod.dart' show SolidFunctionCallStatus, readPod;
import 'package:healthpod/utils/security_key/central_key_manager.dart';

/// Combined blood pressure visualisation widget.
///
/// A widget for visualising both systolic and diastolic blood pressure
/// measurements on a single chart. This widget processes survey data to create an
/// interactive line chart showing blood pressure trends over time, with:
/// * Dual line visualisation for systolic and diastolic readings
/// * Interactive tooltips showing exact values
/// * Summary statistics including averages, minimums, and maximums
/// * Date-based X-axis and pressure-based Y-axis (mmHg)
/// * Color-coded lines and legend for easy differentiation
///
/// The widget expects survey data in a specific format with 'timestamp' and 'responses'
/// fields, where responses contain the blood pressure measurements.

class BPCombinedVisualisation extends StatefulWidget {
  const BPCombinedVisualisation({super.key});

  @override
  State<BPCombinedVisualisation> createState() =>
      _BPCombinedVisualisationState();
}

class _BPCombinedVisualisationState extends State<BPCombinedVisualisation> {
  List<Map<String, dynamic>> _surveyData = [];
  bool _isLoading = true;
  late ThemeData theme;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  Future<void> _loadData() async {
    // Show loading indicator.

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await SurveyData.fetchAllSurveyData(context);
      if (mounted) {
        setState(() {
          _surveyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _surveyData = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  /// Extracts and converts systolic blood pressure data into chart points.
  ///
  /// Returns a list of [FlSpot] objects where:
  /// * X coordinate represents the data point index
  /// * Y coordinate represents the systolic pressure in mmHg.

  List<FlSpot> _getSystolicData() {
    List<FlSpot> spots = [];
    for (var i = 0; i < _surveyData.length; i++) {
      final data = _surveyData[i]['responses'];
      double value =
          _parseNumericValue(data[HealthSurveyConstants.fieldSystolic]);
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  /// Extracts and converts diastolic blood pressure data into chart points.
  ///
  /// Returns a list of [FlSpot] objects where:
  /// * X coordinate represents the data point index
  /// * Y coordinate represents the diastolic pressure in mmHg.

  List<FlSpot> _getDiastolicData() {
    List<FlSpot> spots = [];
    for (var i = 0; i < _surveyData.length; i++) {
      final data = _surveyData[i]['responses'];
      double value =
          _parseNumericValue(data[HealthSurveyConstants.fieldDiastolic]);
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  /// Safely converts various numeric formats to double.
  ///
  /// Handles integers, doubles, and string representations of numbers.
  /// Returns 0.0 if the value cannot be parsed.

  double _parseNumericValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.parse(value);
    debugPrint('Warning: Invalid numeric value: $value');
    return 0.0;
  }

  /// Builds a list of statistical summary widgets.
  ///
  /// Calculates and displays average, minimum, and maximum values for both
  /// systolic and diastolic pressure in the format "systolic/diastolic mmHg".

  List<Widget> _buildStatItems() {
    // Extract values for calculations.

    final systolicValues = _getSystolicData().map((spot) => spot.y).toList();
    final diastolicValues = _getDiastolicData().map((spot) => spot.y).toList();

    // Calculate statistics for systolic pressure.

    final systolicAvg =
        systolicValues.reduce((a, b) => a + b) / systolicValues.length;
    final systolicMin = systolicValues.reduce((a, b) => a < b ? a : b);
    final systolicMax = systolicValues.reduce((a, b) => a > b ? a : b);

    // Calculate statistics for diastolic pressure.

    final diastolicAvg =
        diastolicValues.reduce((a, b) => a + b) / diastolicValues.length;
    final diastolicMin = diastolicValues.reduce((a, b) => a < b ? a : b);
    final diastolicMax = diastolicValues.reduce((a, b) => a > b ? a : b);

    // Build and return the stat items with dividers.

    return [
      StatItem(
        label: 'Average',
        value:
            '${parseNumericInput(systolicAvg)}/${parseNumericInput(diastolicAvg)} mmHg', // ensure int format.
      ),
      Container(
        height: 40,
        width: 1,
        color: theme.dividerColor,
      ),
      StatItem(
        label: 'Min',
        value:
            '${parseNumericInput(systolicMin)}/${parseNumericInput(diastolicMin)} mmHg',
      ),
      Container(
        height: 40,
        width: 1,
        color: theme.dividerColor,
      ),
      StatItem(
        label: 'Max',
        value:
            '${parseNumericInput(systolicMax)}/${parseNumericInput(diastolicMax)} mmHg',
      ),
    ];
  }

  /// Gets the display title and unit for a given metric type.
  Map<String, String> _getMetricInfo(String metricType) {
    switch (metricType) {
      case 'systolic':
        return {'title': 'Systolic Blood Pressure', 'unit': 'mmHg'};
      case 'diastolic':
        return {'title': 'Diastolic Blood Pressure', 'unit': 'mmHg'};
      case 'heart_rate':
        return {'title': 'Heart Rate', 'unit': 'bpm'};
      default:
        return {'title': metricType, 'unit': ''};
    }
  }

  /// Builds a bar chart comparing patient statistics with aggregated statistics.
  /// metricType can be 'systolic', 'diastolic', or 'heart_rate'
  Widget _buildComparisonBarChart(
    Map<String, dynamic> data,
    ThemeData theme,
    String metricType,
  ) {
    try {
      final aggregatedMetric = data['aggregated_statistics']?[metricType];
      final patientMetric = data['patient_statistics']?[metricType];

      if (aggregatedMetric == null || patientMetric == null) {
        return Center(
          child: Text('Unable to load $metricType statistics data'),
        );
      }

      // Extract values
      final aggregatedMean = (aggregatedMetric['mean'] as num?)?.toDouble() ?? 0;
      final aggregatedMedian = (aggregatedMetric['median'] as num?)?.toDouble() ?? 0;
      final aggregatedMin = (aggregatedMetric['min'] as num?)?.toDouble() ?? 0;
      final aggregatedMax = (aggregatedMetric['max'] as num?)?.toDouble() ?? 0;

      final patientMean = (patientMetric['mean'] as num?)?.toDouble() ?? 0;
      final patientMedian = (patientMetric['median'] as num?)?.toDouble() ?? 0;
      final patientMin = (patientMetric['min'] as num?)?.toDouble() ?? 0;
      final patientMax = (patientMetric['max'] as num?)?.toDouble() ?? 0;

      // BarChartGroupData helper function
      BarChartGroupData createBarGroup(
        int index,
        double aggregatedValue,
        double patientValue,
        ThemeData theme,
      ) {
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: aggregatedValue,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: patientValue,
              color: theme.colorScheme.secondary,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }

      final metricInfo = _getMetricInfo(metricType);
      final unit = metricInfo['unit']!;
      final labels = ['Mean', 'Median', 'Min', 'Max'];

      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 220,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => theme.colorScheme.surfaceContainerHighest,
              tooltipBorder: BorderSide(
                color: theme.colorScheme.outline,
                width: 2,
              ),
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rodIndex == 0 ? 'All Patients' : 'You';
                final statType = labels[groupIndex];
                return BarTooltipItem(
                  '$label\n$statType: ${rod.toY.toStringAsFixed(1)} $unit',
                  TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        labels[value.toInt()],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              );
            },
          ),
          borderData: FlBorderData(
            show: false,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
            barGroups: [
              createBarGroup(0, aggregatedMean, patientMean, theme),
              createBarGroup(1, aggregatedMedian, patientMedian, theme),
              createBarGroup(2, aggregatedMin, patientMin, theme),
              createBarGroup(3, aggregatedMax, patientMax, theme),
            ],
        ),
      );
    } catch (e) {
      return Center(
        child: Text('Error building chart: $e'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_surveyData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AppBar(
            title: Row(
              children: [
                // Main title with basic BP explanation.

                MarkdownTooltip(
                  message: '''

                    **Blood Pressure:** A vital measurement of cardiovascular health.
                    It shows how strongly your blood pushes against artery walls.

                    Blood pressure is measured in millimeters of mercury (mmHg) and recorded as two numbers: systolic/diastolic.

                    * **Systolic**: Upper number - Pressure when heart contracts

                    * **Diastolic**: Lower number - Pressure when heart relaxes

                  ''',
                  child: Row(
                    children: [
                      Text(
                        'Blood Pressure Trends',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.surface,
            actions: [
              // MarkdownTooltip explaining BP Classification ranges.

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: MarkdownTooltip(
                  message: '''

                    **BP Classifications (AHA)**

                    * **Normal Blood Pressure:** <120/<80 mmHg

                    * **Elevated Blood Pressure:** 120-129/<80 mmHg

                    * **Stage 1 High Blood Pressure (Hypertension):** 130-139/80-89 mmHg

                    * **Stage 2 Hypertension:** ≥140/≥90 mmHg

                    * **Hypertensive Crisis:** >180/>120 mmHg (Seek medical attention)

                    * **Low Blood Pressure (Hypotension):** <90/<60 mmHg

                  ''',
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              // MarkdownTooltip for additional BP information.

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: MarkdownTooltip(
                  message: '''

                    **BP Health Information**

                    * Blood pressure can vary throughout the day due to activity, stress, or other factors.

                    * A single high reading doesn't necessarily mean you have hypertension.

                    * Consistent high readings should be discussed with your healthcare professional.

                    * Ideal blood pressure ranges vary depending on age, health conditions, and individual circumstances.

                    * Consult your doctor for personalised advice.

                    * Healthy lifestyle helps maintain normal blood pressure:
                        - Regular exercise
                        - Balanced diet
                        - Stress management
                        - Limited sodium & alcohol

                  ''',
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),

              // Summary button with file upload to the server
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: IconButton(
                  icon: Icon(
                    Icons.analytics,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        String fileContent = '';
                        bool hasFileContent = false;
                        bool isLoading = false;
                        String? errorText;
                        const String feature = 'blood_pressure';
                        const String serverFileName =
                            'overall_summary.json.enc.ttl';
                        bool hasAttemptedInitialLoad = false;
                        
                        // PageView controller for carousel
                        final pageController = PageController(initialPage: 0);
                        int currentPage = 0;
                        final metrics = ['systolic', 'diastolic', 'heart_rate'];

                        Future<void> loadFromServer(
                          BuildContext dialogContext,
                          void Function(void Function()) setStateDialog,
                        ) async {
                          if (!dialogContext.mounted) return;
                          setStateDialog(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            // Check if security key is available
                            await CentralKeyManager.instance.ensureSecurityKey(
                              dialogContext,
                              const Text(
                                'Please enter your security key to access your health data',
                              ),
                            );

                            if (!dialogContext.mounted) return;

                            String? content = await readPod(
                              '$feature/$serverFileName',
                              dialogContext,
                              const Text('Loading summary'),
                            );

                            if ( content == SolidFunctionCallStatus.fail.toString() 
                              || content == SolidFunctionCallStatus.notLoggedIn.toString()
                            ) {
                              throw Exception('Unable to read summary file');
                            }

                            String printable;
                            try {
                              final dynamic parsed = jsonDecode(content);
                              printable = const JsonEncoder.withIndent('  ').convert(parsed);
                            } catch (_) {
                              throw Exception('Failed to read summary file');
                            }

                            if (!dialogContext.mounted) return;
                            setStateDialog(() {
                              fileContent = printable;
                              hasFileContent = true;
                            });
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setStateDialog(() {
                                errorText = 'Error loading from server: $e';
                              });
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setStateDialog(() {
                                isLoading = false;
                              });
                            }
                          }
                        }

                        return StatefulBuilder(
                          builder: (dialogContext, setStateDialog) {
                            // Load from server upon opening the dialog
                            if (!hasAttemptedInitialLoad) {
                              hasAttemptedInitialLoad = true;
                              Future.microtask(
                                () => loadFromServer(
                                  dialogContext,
                                  setStateDialog,
                                ),
                              );
                            }

                            // Parse JSON data for chart
                            Map<String, dynamic>? parsedData;
                            if (hasFileContent && fileContent.isNotEmpty) {
                              try {
                                parsedData = jsonDecode(fileContent);
                              } catch (e) {
                                parsedData = null;
                              }
                            }

                            return AlertDialog(
                              title: Text('Blood Pressure Summary'),
                              content: SizedBox(
                                width: 800,
                                height: 520,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Here\'s the summary statistics across 10 patients'),
                                      SizedBox(height: 16),
                                      Container(
                                        alignment: Alignment.centerLeft,
                                        margin: EdgeInsets.only(bottom: 16),
                                        child: SizedBox(
                                          width: 200,
                                          child: ElevatedButton.icon(
                                            onPressed: () => loadFromServer(dialogContext, setStateDialog),
                                            icon: Icon(Icons.cloud_download),
                                            label: Text('Refetch data'),
                                          ),
                                        ),
                                      ),

                                      if (isLoading) ...[
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('Loading data...'),
                                          ],
                                        ),
                                      ],

                                      if (errorText != null) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          errorText!,
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],

                                      // Bar chart carousel display
                                      if (hasFileContent && parsedData != null) ...[
                                        // Navigation arrows and title
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.arrow_back_ios),
                                              onPressed: currentPage > 0
                                                ? () {
                                                    pageController.previousPage(
                                                      duration: Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut,
                                                    );
                                                  }: null,
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    _getMetricInfo(metrics[currentPage])['title']!,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    '${currentPage + 1} of ${metrics.length}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.arrow_forward_ios),
                                              onPressed: currentPage < metrics.length - 1
                                                ? () {
                                                    pageController.nextPage(
                                                      duration: Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut,
                                                    );
                                                  }
                                                : null,
                                            ),
                                          ],
                                        ),
                                        
                                        SizedBox(height: 10),
                                        
                                        // PageView carousel
                                        SizedBox(
                                          height: 350,
                                          child: PageView.builder(
                                            controller: pageController,
                                            onPageChanged: (index) {
                                              setStateDialog(() {
                                                currentPage = index;
                                              });
                                            },
                                            itemCount: metrics.length,
                                            itemBuilder: (context, index) {
                                              return Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: theme.colorScheme.outline,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: _buildComparisonBarChart(
                                                  parsedData!,
                                                  theme,
                                                  metrics[index],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        
                                        SizedBox(height: 12),
                                        
                                        // Legend
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text('All Patients'),
                                              ],
                                            ),
                                            SizedBox(width: 24),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.secondary,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text('You'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              
              // AHA Link Button.

              Padding(
                padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                child: MarkdownTooltip(
                  message: '''

                  **American Heart Association**

                  Click to visit [AHA's website](https://www.heart.org) for expert guidance on heart health and blood pressure management.

                  ''',
                  child: IconButton(
                    icon: Icon(
                      Icons.open_in_new,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => UrlLauncherUtil.launchAHA(context),
                  ),
                ),
              ),
            ],
          ),
          // Main chart area showing blood pressure trends.

          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    backgroundColor: theme.colorScheme.surface,
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        /// Danger systolic threshold line (180 mmHg).
                        ///
                        /// Uses a dashed red line to indicate dangerous systolic levels.

                        HorizontalLine(
                          y: 180,
                          color: theme.colorScheme.error,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                            alignment: Alignment.topRight,
                            labelResolver: (line) => 'Danger',
                          ),
                        ),

                        /// Threshold line indicating normal systolic pressure limit.
                        ///
                        /// Uses a dashed purple line matching the systolic data color.
                        /// Upper systolic threshold line (120 mmHg).

                        HorizontalLine(
                          y: 120,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                          strokeWidth: 1.5,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: false, // Hide by default.
                          ),
                        ),

                        /// Threshold line indicating normal diastolic pressure limit.
                        ///
                        /// Uses a dashed teal line matching the diastolic data color.
                        /// Upper diastolic threshold line (80 mmHg).

                        HorizontalLine(
                          y: 80,
                          color: theme.colorScheme.secondary
                              .withValues(alpha: 0.7),
                          strokeWidth: 1.5,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: false, // Hide by default.
                          ),
                        ),
                      ],
                    ),

                    /// Touch interaction configuration for data point inspection.

                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        // tooltipRoundedRadius: 8,
                        getTooltipColor: (touchedSpots) =>
                            theme.colorScheme.surfaceContainerHighest,
                        tooltipBorder: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        tooltipMargin: 8,
                        maxContentWidth: 300,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipHorizontalAlignment:
                            FLHorizontalAlignment.center,

                        /// Custom tooltip content generator showing pressure values and additional data.
                        /// Removed normal ranges for each type.

                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          if (touchedSpots.isEmpty) return [];

                          // Get the index of the data point from the first spot.

                          final index = touchedSpots[0].x.toInt();
                          final data = _surveyData[index]['responses'];

                          // Extract shared metadata.

                          final heartRate =
                              data[HealthSurveyConstants.fieldHeartRate] ??
                                  'N/A';
                          final notes =
                              data[HealthSurveyConstants.fieldNotes] ?? '';
                          final timestamp =
                              DateTime.parse(_surveyData[index]['timestamp']);
                          String timeStr =
                              DateFormat('dd MMMM y h:mm a').format(timestamp);

                          // Get both systolic and diastolic values from the data.

                          final systolicValue = parseNumericInput(
                            _parseNumericValue(
                              data[HealthSurveyConstants.fieldSystolic],
                            ),
                          );
                          final diastolicValue = parseNumericInput(
                            _parseNumericValue(
                              data[HealthSurveyConstants.fieldDiastolic],
                            ),
                          );

                          // Create a consistent tooltip regardless of which point was touched.

                          final List<String> contentLines = [
                            'BLOOD PRESSURE: $systolicValue/$diastolicValue mmHg',
                            '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
                            '🕒 Time: $timeStr',
                            '❤️ Heart Rate: ${parseNumericInput(_parseNumericValue(heartRate))} bpm',
                          ];

                          // Add notes if they exist.

                          if (notes.isNotEmpty) {
                            contentLines.add('📝 Notes: $notes');
                          }

                          // Join lines with consistent newlines.

                          final tooltipContent = contentLines.join('\n');

                          // We need to return an item for each touched spot to satisfy fl_chart requirements.
                          // Make the first item visible with content, and hide the rest with empty content.

                          final List<LineTooltipItem> items = [];

                          // Add a tooltip item for each touched spot.

                          for (int i = 0; i < touchedSpots.length; i++) {
                            // Only the first tooltip will actually be visible with content.

                            if (i == 0) {
                              items.add(
                                LineTooltipItem(
                                  tooltipContent,
                                  TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    height: 1.8,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              );
                            } else {
                              // Add empty tooltip items for other spots, they won't be visible.

                              items.add(
                                LineTooltipItem(
                                  '',
                                  const TextStyle(fontSize: 0),
                                ),
                              );
                            }
                          }

                          return items;
                        },
                      ),
                      handleBuiltInTouches: true,
                      touchSpotThreshold: 20,
                    ),

                    /// Grid configuration for better data readability.
                    /// Uses light grey dashed lines for subtle visual guidance.

                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 20,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                          strokeWidth: 0.5,
                          dashArray: [5, 5],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                          strokeWidth: 0.5,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    // Configure axis titles and labels.

                    titlesData: FlTitlesData(
                      /// X-axis shows dates with dynamic year display.

                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 &&
                                index < _surveyData.length &&
                                value == index.toDouble()) {
                              final date = DateTime.parse(
                                _surveyData[index]['timestamp'],
                              );

                              // Show year if this is first data point or if year changed from previous point.

                              bool showYear = index == 0 ||
                                  (index > 0 &&
                                      DateTime.parse(
                                            _surveyData[index - 1]['timestamp'],
                                          ).year !=
                                          date.year);

                              /// Date label with hover tooltip showing time.

                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: MarkdownTooltip(
                                  message: '''

                                    **Time:** ${DateFormat('HH:mm').format(date)}

                                  ''',
                                  child: Text(
                                    '${date.day} ${getMonthAbbrev(date.month)}${showYear ? " '${(date.year % 100).toString().padLeft(2, '0')}" : ""}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      // Y-axis configuration showing pressure values.

                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      /// Hide unnecessary axis titles.

                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),

                    /// Chart border for visual containment.

                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: theme.dividerColor),
                    ),

                    /// Chart value range configuration.

                    minX: 0,
                    maxX: (_surveyData.length - 1).toDouble(),
                    minY: 40, // Minimum expected diastolic pressure.
                    maxY: 200, // Maximum expected systolic pressure.
                    lineBarsData: [
                      // Systolic pressure line configuration.

                      // Bright purple and teal lines for systolic and diastolic pressure.
                      // From Bang Wong's colourblind-safe palette.

                      LineChartBarData(
                        spots: _getSystolicData(),
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: theme.colorScheme.surface,
                              strokeWidth: 3,
                              strokeColor: theme.colorScheme.primary,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(show: false),
                      ),
                      // Diastolic pressure line configuration.

                      LineChartBarData(
                        spots: _getDiastolicData(),
                        isCurved: true,
                        color: theme.colorScheme.secondary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: theme.colorScheme.surface,
                              strokeWidth: 3,
                              strokeColor: theme.colorScheme.secondary,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend and statistics card.

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 12.0,
              ),
              child: Column(
                children: [
                  // Legend items.

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Systolic pressure legend item.
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Colour indicator dot.

                            Flexible(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Systolic blood pressure tooltip explaining the measurement.

                            MarkdownTooltip(
                              message: '''

                                **Systolic Blood Pressure:** The top number in your reading.
                                Measures the pressure when your heart contracts to pump blood.
                                Normal reading is typically below 120 mmHg.

                              ''',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width:
                                        50, // Adjust based on available space.
                                    child: Text(
                                      'Systolic',
                                      overflow: TextOverflow.ellipsis,
                                      softWrap:
                                          false, // Prevents multi-line issues.
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Info icon.

                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Icon(
                                        Icons.info_outline,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Diastolic pressure legend item.

                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Colour indicator dot.

                            Flexible(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Diastolic blood pressure tooltip explaining the measurement.

                            MarkdownTooltip(
                              message: '''

                                **Diastolic Blood Pressure:** The bottom number in your reading.
                                Measures the pressure when your heart relaxes between beats.
                                Normal reading is typically below 80 mmHg.

                              ''',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(child: const Text('Diastolic')),
                                  const SizedBox(width: 4),
                                  // Info icon.

                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit
                                          .scaleDown, // Scales down to fit available space.
                                      child: Icon(
                                        Icons.info_outline,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scrollable stats row.

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildStatItems(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
