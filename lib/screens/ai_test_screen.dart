import 'package:flutter/material.dart';
import 'package:mission_master/services/sentiment_analysis_service.dart';
import 'package:mission_master/constants/colors.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({Key? key}) : super(key: key);

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  final TextEditingController _textController = TextEditingController();
  SentimentResult? _sentimentResult;
  TeamMoodAnalysis? _moodAnalysis;
  bool _isAnalyzing = false;

  // Test texts in Vietnamese
  final List<String> _testTexts = [
    // ✅ Positive texts
    'Task hoàn thành rất tốt! Team làm việc tuyệt vời 😊',
    'Cảm ơn mọi người đã support. Dự án này thành công nhờ sự cố gắng của tất cả 👍',
    'UI design này đẹp quá! Perfect cho app của chúng ta 🎉',
    'Code review xong rồi, không có bug gì. Excellent work! ✅',
    'Demo thành công, khách hàng rất hài lòng! 🎊',
    'Release version mới smooth, team đã làm tuyệt vời! 👏',
    'Sprint hoàn thành on time, all tasks done perfectly ⭐',
    
    // ❌ Negative texts - Stress & Burnout  
    'Task này khó quá, không biết làm sao 😰',
    'Deadline gấp quá, team đang stress và mệt lắm',
    'Có nhiều bug trong code, phải fix lại từ đầu 😢',
    'Stress quá, deadline gấp, team mệt lắm 😰',
    'Burnout quá rồi, overload work không thể handle nổi',
    'Server crash liên tục, khách hàng complain nhiều 😭',
    'Task delay, budget vượt quá nhiều, project thất bại',
    'Team members nghỉ việc, thiếu người làm, áp lực lắm 😞',
    'Bug critical không fix được, deadline miss rồi ❌',
    'Overload quá, không kịp làm hết task này tuần',
    'Dự án bị delay, khách hàng không hài lòng lắm',
    'Mệt lắm rồi, work từ sáng đến tối vẫn không xong 😴',
    
    // 😐 Neutral texts
    'Meeting lúc 2h chiều để review tiến độ dự án',
    'Cần update document cho API mới',
    'Task đang in progress, dự kiến hoàn thành tuần tới',
    'Sprint planning cho tuần tới, assign tasks cho team',
    'Review code pull request, merge vào main branch',
    'Update dependency packages, test compatibility',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🤖 AI Sentiment Analysis Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Test Input',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Nhập text để phân tích sentiment...\nVí dụ: "Task hoàn thành tốt, team làm việc tuyệt vời!" hoặc "Stress quá, deadline gấp"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _analyzeText,
                            icon: Icon(Icons.psychology),
                            label: Text('Phân tích Sentiment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _testTeamMood,
                          icon: Icon(Icons.group),
                          label: Text('Test Team Mood'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Test Buttons
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚀 Quick Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _testTexts.map((text) {
                        final sentiment = SentimentAnalysisService.analyzeSentiment(text);
                        return GestureDetector(
                          onTap: () {
                            _textController.text = text;
                            _analyzeText();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getSentimentColor(sentiment.label).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getSentimentColor(sentiment.label).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getSentimentIcon(sentiment.label),
                                  size: 16,
                                  color: _getSentimentColor(sentiment.label),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    text.length > 30 ? '${text.substring(0, 30)}...' : text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getSentimentColor(sentiment.label),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Results Section
            if (_sentimentResult != null) _buildSentimentResult(),
            if (_moodAnalysis != null) _buildMoodAnalysis(),
            
            const SizedBox(height: 20),
            
            // How it works
            _buildHowItWorks(),
          ],
        ),
      ),
    );
  }

  void _analyzeText() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập text để phân tích')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _sentimentResult = null;
    });

    // Simulate loading delay
    Future.delayed(Duration(milliseconds: 500), () {
      final result = SentimentAnalysisService.analyzeSentiment(_textController.text);
      setState(() {
        _sentimentResult = result;
        _isAnalyzing = false;
      });
    });
  }

  void _testTeamMood() async {
    setState(() {
      _isAnalyzing = true;
      _moodAnalysis = null;
    });

    try {
      // Use a test project ID - in real app this would be actual project
      final analysis = await SentimentAnalysisService.analyzeTeamMood('test-project-id');
      setState(() {
        _moodAnalysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Widget _buildSentimentResult() {
    final result = _sentimentResult!;
    final color = _getSentimentColor(result.label);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: color),
                const SizedBox(width: 8),
                Text(
                  '📊 Kết quả Sentiment Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Score visualization
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_getSentimentIcon(result.label), color: color, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSentimentLabel(result.label),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: ${result.score.toStringAsFixed(2)} | Magnitude: ${result.magnitude.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sentiment Score (-1.0 to 1.0)', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (result.score + 1) / 2, // Convert -1,1 to 0,1
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      const SizedBox(height: 8),
                      Text('Magnitude (0.0 to 1.0)', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: result.magnitude,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Giải thích:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getExplanation(result),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodAnalysis() {
    final analysis = _moodAnalysis!;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👥 Team Mood Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            
            Text('Overall Mood: ${analysis.moodLabel}'),
            Text('Member Count: ${analysis.memberCount}'),
            Text('Confidence: ${(analysis.confidence * 100).round()}%'),
            
            if (analysis.stressedMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('⚠️ Stressed Members:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...analysis.stressedMembers.map((member) => 
                Text('• ${member.email} (${(member.stressLevel * 100).round()}% stress)')
              ),
            ],
            
            const SizedBox(height: 12),
            Text('💡 Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...analysis.recommendations.map((rec) => Text('• $rec')),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ How It Works',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            
            _buildFeatureItem('🔍', 'Keyword Analysis', 'Phân tích từ khóa tích cực/tiêu cực trong tiếng Việt và English'),
            _buildFeatureItem('📊', 'Score Calculation', 'Tính điểm sentiment từ -1.0 (rất tiêu cực) đến 1.0 (rất tích cực)'),
            _buildFeatureItem('🎯', 'Magnitude Detection', 'Đo cường độ cảm xúc (0.0 = nhẹ, 1.0 = mạnh)'),
            _buildFeatureItem('😊', 'Emoji Support', 'Hỗ trợ phân tích emoji: 😊 👍 🎉 😰 😢'),
            _buildFeatureItem('🤖', 'Real-time Analysis', 'Phân tích ngay lập tức không cần gửi data lên server'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(String label) {
    switch (label) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getSentimentIcon(String label) {
    switch (label) {
      case 'positive':
        return Icons.sentiment_very_satisfied;
      case 'negative':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _getSentimentLabel(String label) {
    switch (label) {
      case 'positive':
        return 'Tích cực 😊';
      case 'negative':
        return 'Tiêu cực 😕';
      default:
        return 'Trung tính 😐';
    }
  }

  String _getExplanation(SentimentResult result) {
    if (result.label == 'positive') {
      return 'Text này chứa nhiều từ khóa tích cực như "tốt", "tuyệt", "hoàn thành", "cảm ơn". AI đánh giá đây là sentiment tích cực.';
    } else if (result.label == 'negative') {
      return 'Text này chứa từ khóa tiêu cực như "khó", "stress", "mệt", "bug", "delay". AI phát hiện sentiment tiêu cực.';
    } else {
      return 'Text này không có đủ từ khóa cảm xúc mạnh hoặc cân bằng giữa tích cực/tiêu cực. AI đánh giá là trung tính.';
    }
  }
} 