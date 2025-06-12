import 'package:flutter/material.dart';
import 'package:mission_master/services/sentiment_analysis_service.dart';
import 'package:mission_master/constants/colors.dart';

class TeamMoodWidget extends StatefulWidget {
  final String projectId;
  final String projectName;

  const TeamMoodWidget({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<TeamMoodWidget> createState() => _TeamMoodWidgetState();
}

class _TeamMoodWidgetState extends State<TeamMoodWidget> {
  TeamMoodAnalysis? _moodAnalysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamMood();
  }

  Future<void> _loadTeamMood() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analysis = await SentimentAnalysisService.analyzeTeamMood(widget.projectId);
      setState(() {
        _moodAnalysis = analysis;
        _isLoading = false;
      });

      // Save analysis to Firebase
      await SentimentAnalysisService.saveMoodAnalysis(analysis);
    } catch (e) {
      print('Error loading team mood: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🤖 AI Team Mood Analysis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'Phân tích tâm lý team real-time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue[700]),
                  onPressed: _loadTeamMood,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            _isLoading
                ? _buildLoadingState()
                : _moodAnalysis != null
                    ? _buildMoodAnalysis(_moodAnalysis!)
                    : _buildErrorState(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              'Đang phân tích mood team...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodAnalysis(TeamMoodAnalysis analysis) {
    final moodColor = _getMoodColor(analysis.overallMood);
    final trendIcon = _getTrendIcon(analysis.trendDirection);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Mood Score
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: moodColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: moodColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Mood Score Circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: moodColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: moodColor, width: 3),
                ),
                child: Center(
                  child: Text(
                    '${(analysis.overallMood * 100).round()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: moodColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Mood Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          analysis.moodLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: moodColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(trendIcon, color: moodColor, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${analysis.memberCount} thành viên',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Độ tin cậy: ${(analysis.confidence * 100).round()}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Stressed Members Alert
        if (analysis.stressedMembers.isNotEmpty)
          _buildStressedMembersAlert(analysis.stressedMembers),
        
        const SizedBox(height: 12),
        
        // Recommendations
        _buildRecommendations(analysis.recommendations),
      ],
    );
  }

  Widget _buildStressedMembersAlert(List<StressedMember> stressedMembers) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                '⚠️ Thành viên có dấu hiệu stress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...stressedMembers.map((member) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStressColor(member.stressLevel),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${member.email} (${(member.stressLevel * 100).round()}% stress)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<String> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💡 AI Recommendations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...recommendations.take(3).map((recommendation) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              'Không thể phân tích mood',
              style: TextStyle(color: Colors.grey[600]),
            ),
            TextButton(
              onPressed: _loadTeamMood,
              child: Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double mood) {
    if (mood > 0.3) return Colors.green;
    if (mood > 0.0) return Colors.blue;
    if (mood > -0.3) return Colors.orange;
    return Colors.red;
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'improving':
        return Icons.trending_up;
      case 'declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getStressColor(double stressLevel) {
    if (stressLevel > 0.8) return Colors.red;
    if (stressLevel > 0.6) return Colors.orange;
    return Colors.yellow;
  }
}

/// Quick Mood Indicator for smaller spaces
class QuickMoodIndicator extends StatelessWidget {
  final double moodScore;
  final String moodLabel;
  final VoidCallback? onTap;

  const QuickMoodIndicator({
    Key? key,
    required this.moodScore,
    required this.moodLabel,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final moodColor = _getMoodColor(moodScore);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: moodColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: moodColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 16, color: moodColor),
            const SizedBox(width: 6),
            Text(
              moodLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: moodColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(moodScore * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                color: moodColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double mood) {
    if (mood > 0.3) return Colors.green;
    if (mood > 0.0) return Colors.blue;
    if (mood > -0.3) return Colors.orange;
    return Colors.red;
  }
} 