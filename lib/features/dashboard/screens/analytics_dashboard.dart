import 'dart:async';
import 'dart:math' as math;
import 'package:digitalisapp/services/analytics_api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverAnalyticsDashboard extends StatefulWidget {
  @override
  State<DriverAnalyticsDashboard> createState() =>
      _DriverAnalyticsDashboardState();
}

class _DriverAnalyticsDashboardState extends State<DriverAnalyticsDashboard>
    with TickerProviderStateMixin {
  final AnalyticsApiService _analyticsService = AnalyticsApiService();

  // Data
  Map<String, dynamic> _performanceData = {};
  Map<String, dynamic> _deliveryTimeData = {};
  Map<String, dynamic> _routeEfficiencyData = {};
  Map<String, dynamic> _peakHoursData = {};
  List<Map<String, dynamic>> _driverComparison = [];

  // UI State
  bool _loading = true;
  String _selectedTimeRange = '7d';
  int? _selectedDriverId;

  // Animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _chartController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _chartController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _initializeData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _chartController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(minutes: 2), (_) {
      _refreshData();
    });
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);

    final now = DateTime.now();
    final from = _getFromDate(now);

    try {
      final results = await Future.wait([
        _analyticsService.getDriverPerformance(from: from, to: now),
        // _analyticsService.getDeliveryTimeAnalytics(from: from, to: now),
        // _analyticsService.getRouteEfficiency(from: from, to: now),
        // _analyticsService.getPeakHoursAnalysis(from: from, to: now),
        // _analyticsService.getDriverComparison(from: from, to: now),
      ]);

      setState(() {
        _performanceData = results[0];
        _deliveryTimeData = results[1];
        _routeEfficiencyData = results[2];
        _peakHoursData = results[3];
        _driverComparison = List<Map<String, dynamic>>.from(
          results[4]['drivers'] ?? [],
        );
        _loading = false;
      });

      // Start animations
      _fadeController.forward();
      _slideController.forward();
      _chartController.forward();
    } catch (e) {
      print('Error loading analytics data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _initializeData();
  }

  DateTime _getFromDate(DateTime now) {
    switch (_selectedTimeRange) {
      case '1d':
        return now.subtract(Duration(days: 1));
      case '7d':
        return now.subtract(Duration(days: 7));
      case '30d':
        return now.subtract(Duration(days: 30));
      case '3m':
        return now.subtract(Duration(days: 90));
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (_loading)
            SliverFillRemaining(child: _buildLoadingState())
          else ...[
            _buildTimeRangeSelector(),
            _buildKPICards(),
            _buildChartsSection(),
            _buildDriverLeaderboard(),
            _buildBottomPadding(),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.inter(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.purple.shade50],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.grey.shade700),
          onPressed: _refreshData,
        ),
        IconButton(
          icon: Icon(Icons.settings, color: Colors.grey.shade700),
          onPressed: () {
            // TODO: Settings dialog
          },
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTimeRangeChip('1d', 'Danas'),
              _buildTimeRangeChip('7d', '7 dana'),
              _buildTimeRangeChip('30d', '30 dana'),
              _buildTimeRangeChip('3m', '3 meseca'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeChip(String value, String label) {
    final isSelected = _selectedTimeRange == value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTimeRange = value);
        _initializeData();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildKPICard(
                title: 'Ukupne dostave',
                value: (_performanceData['total_deliveries'] ?? 0).toString(),
                subtitle: '+12% od prošle nedelje',
                icon: Icons.local_shipping,
                color: Colors.blue,
                trend: 12.0,
              ),
              _buildKPICard(
                title: 'Prosečno vreme',
                value:
                    '${(_performanceData['avg_delivery_time'] ?? 0).toStringAsFixed(1)} min',
                subtitle: '-5 min poboljšanje',
                icon: Icons.access_time,
                color: Colors.green,
                trend: -8.5,
              ),
              _buildKPICard(
                title: 'Efikasnost rute',
                value:
                    '${(_routeEfficiencyData['efficiency_score'] ?? 0).toStringAsFixed(1)}%',
                subtitle: '+3% ovaj mesec',
                icon: Icons.timeline,
                color: Colors.purple,
                trend: 3.2,
              ),
              _buildKPICard(
                title: 'Zadovoljstvo',
                value:
                    '${(_performanceData['satisfaction_score'] ?? 0).toStringAsFixed(1)}/5',
                subtitle: 'Odlično!',
                icon: Icons.sentiment_very_satisfied,
                color: Colors.orange,
                trend: 2.1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double trend,
  }) {
    return Container(
      width: 200,
      margin: EdgeInsets.only(right: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trend >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trend >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: trend >= 0 ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${trend.abs().toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: trend >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Spacer(),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Column(
          children: [
            SizedBox(height: 20),
            _buildDeliveryTimeChart(),
            SizedBox(height: 20),
            _buildPeakHoursChart(),
            SizedBox(height: 20),
            _buildRouteEfficiencyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTimeChart() {
    final deliveryTimes = List<Map<String, dynamic>>.from(
      _deliveryTimeData['hourly_data'] ?? [],
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vremena dostave tokom dana',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 250,
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (context, child) {
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}h');
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: deliveryTimes.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            (entry.value['avg_time'] ?? 0).toDouble() *
                                _chartController.value,
                          );
                        }).toList(),
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                          ],
                        ),
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400.withOpacity(0.3),
                              Colors.purple.shade400.withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursChart() {
    final peakHours = List<Map<String, dynamic>>.from(
      _peakHoursData['hourly_deliveries'] ?? [],
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Špicevi časovi dostave',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 250,
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (context, child) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: peakHours.isEmpty
                        ? 100
                        : (peakHours
                                  .map((h) => h['deliveries'] ?? 0)
                                  .toList()
                                  .cast<num>()
                                  .reduce(math.max)
                                  .toDouble()) *
                              1.2,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}h');
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: peakHours.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY:
                                (entry.value['deliveries'] ?? 0).toDouble() *
                                _chartController.value,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.red.shade400,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteEfficiencyChart() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Efikasnost rute',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (context, child) {
                final efficiency =
                    (_routeEfficiencyData['efficiency_score'] ?? 85.0)
                        .toDouble();
                final animatedEfficiency = efficiency * _chartController.value;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: animatedEfficiency / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          efficiency >= 90
                              ? Colors.green
                              : efficiency >= 75
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${animatedEfficiency.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          'Efikasnost',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverLeaderboard() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top vozači',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 20),
            ..._driverComparison
                .take(5)
                .map((driver) => _buildDriverCard(driver)),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = driver['name'] ?? 'N/A';
    final deliveries = driver['total_deliveries'] ?? 0;
    final efficiency = (driver['efficiency_score'] ?? 0.0).toDouble();
    final rating = (driver['rating'] ?? 0.0).toDouble();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '$deliveries dostava',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: efficiency >= 90
                      ? Colors.green.shade100
                      : efficiency >= 80
                      ? Colors.orange.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${efficiency.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: efficiency >= 90
                        ? Colors.green.shade700
                        : efficiency >= 80
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Učitavanje analytics...',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPadding() {
    return SliverToBoxAdapter(child: SizedBox(height: 40));
  }
}
