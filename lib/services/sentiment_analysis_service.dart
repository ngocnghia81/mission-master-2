import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'dart:math';

/// 🤖 AI Sentiment Analysis Service - Phát hiện stress team
class SentimentAnalysisService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Phân tích sentiment của một đoạn text
  static SentimentResult analyzeSentiment(String text) {
    if (text.trim().isEmpty) {
      return SentimentResult(score: 0.0, magnitude: 0.0, label: 'neutral');
    }
    
    // Normalize text
    final normalizedText = text.toLowerCase().trim();
    
    // Vietnamese sentiment keywords
    final positiveKeywords = {
      'tốt': 0.8, 'tuyệt': 0.9, 'hoàn thành': 0.7, 'xong': 0.6, 'ok': 0.5,
      'good': 0.7, 'great': 0.9, 'excellent': 0.9, 'done': 0.6, 'finished': 0.7,
      'thành công': 0.8, 'đẹp': 0.6, 'cảm ơn': 0.7, 'thanks': 0.7,
      'hài lòng': 0.8, 'vui': 0.7, 'happy': 0.8, 'perfect': 0.9,
      '👍': 0.8, '😊': 0.8, '🎉': 0.9, '✅': 0.7, '👏': 0.8
    };
    
    final negativeKeywords = {
      // Stress & Mental Health
      'stress': -0.9, 'áp lực': -0.8, 'burnout': -0.9, 'overload': -0.8,
      'mệt': -0.7, 'tired': -0.7, 'kiệt sức': -0.9, 'exhausted': -0.8,
      'overwhelmed': -0.8, 'quá tải': -0.8, 'căng thẳng': -0.8,
      
      // Work Issues
      'khó': -0.6, 'khó khăn': -0.7, 'không kịp': -0.8, 'delay': -0.7, 
      'trễ': -0.7, 'late': -0.6, 'miss deadline': -0.9, 'quá hạn': -0.8,
      
      // Technical Problems
      'bug': -0.6, 'lỗi': -0.6, 'error': -0.6, 'fail': -0.8,
      'crash': -0.8, 'critical': -0.7, 'hotfix': -0.6,
      
      // Project Failures
      'thất bại': -0.8, 'vấn đề': -0.6, 'problem': -0.6, 'issue': -0.5,
      'complain': -0.7, 'không hài lòng': -0.7, 'unsatisfied': -0.7,
      
      // Extreme Negative
      'tồi': -0.8, 'bad': -0.7, 'terrible': -0.9, 'awful': -0.9,
      'không thể': -0.7, 'impossible': -0.8, 'khủng khiếp': -0.9,
      'nightmare': -0.9, 'disaster': -0.9,
      
      // Work Environment
      'nghỉ việc': -0.8, 'quit': -0.8, 'resign': -0.8, 'thiếu người': -0.7,
      'understaffed': -0.7, 'shortage': -0.6,
      
      // Emojis
      '😞': -0.7, '😢': -0.8, '😰': -0.8, '😭': -0.9, '❌': -0.6,
      '😴': -0.6, '💔': -0.8, '😣': -0.7, '😖': -0.7, '😫': -0.8
    };
    
    final urgencyKeywords = {
      'gấp': 0.3, 'urgent': 0.3, 'asap': 0.4, 'ngay': 0.2,
      'deadline': 0.2, 'hạn': 0.2, 'rush': 0.3
    };
    
    double score = 0.0;
    double magnitude = 0.0;
    int wordCount = 0;
    
    // Analyze positive sentiment
    positiveKeywords.forEach((keyword, weight) {
      if (normalizedText.contains(keyword)) {
        score += weight;
        magnitude += weight.abs();
        wordCount++;
      }
    });
    
    // Analyze negative sentiment
    negativeKeywords.forEach((keyword, weight) {
      if (normalizedText.contains(keyword)) {
        score += weight;
        magnitude += weight.abs();
        wordCount++;
      }
    });
    
    // Analyze urgency (adds to magnitude but neutral sentiment)
    urgencyKeywords.forEach((keyword, weight) {
      if (normalizedText.contains(keyword)) {
        magnitude += weight;
        wordCount++;
      }
    });
    
    // Normalize scores
    if (wordCount > 0) {
      score = (score / wordCount).clamp(-1.0, 1.0);
      magnitude = (magnitude / wordCount).clamp(0.0, 1.0);
    }
    
    // Determine label
    String label;
    if (score > 0.3) label = 'positive';
    else if (score < -0.3) label = 'negative';
    else label = 'neutral';
    
    return SentimentResult(
      score: score,
      magnitude: magnitude,
      label: label,
    );
  }
  
  /// Phân tích mood của team trong project
  static Future<TeamMoodAnalysis> analyzeTeamMood(String projectId) async {
    try {
      final currentUserEmail = Auth.auth.currentUser?.email ?? '';
      if (currentUserEmail.isEmpty) {
        throw Exception('User not authenticated');
      }
      
      // Lấy comments từ tasks trong 7 ngày qua
      final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
      
      // Get all tasks in project
      final tasksSnapshot = await _firestore
          .collection('Tasks')
          .doc(projectId)
          .collection('projectTasks')
          .get();
      
      List<MessageSentiment> allMessages = [];
      Map<String, List<double>> memberSentiments = {};
      
      // Analyze task descriptions and any comments
      for (var taskDoc in tasksSnapshot.docs) {
        final taskData = taskDoc.data();
        final members = List<String>.from(taskData['Members'] ?? []);
        
        // Analyze task description
        final description = taskData['description'] ?? '';
        if (description.isNotEmpty) {
          final sentiment = analyzeSentiment(description);
          allMessages.add(MessageSentiment(
            text: description,
            sentiment: sentiment,
            author: taskData['createdBy'] ?? 'unknown',
            timestamp: DateTime.now(),
          ));
        }
        
        // Simulate some member activity sentiment (in real app, get from comments)
        for (String member in members) {
          if (!memberSentiments.containsKey(member)) {
            memberSentiments[member] = [];
          }
          
          // Simulate member sentiment based on task status
          final status = taskData['status'] ?? 'none';
          double simulatedSentiment = 0.0;
          
          switch (status.toLowerCase()) {
            case 'completed':
            case 'hoàn thành':
              simulatedSentiment = 0.7;
              break;
            case 'in progress':
            case 'đang thực hiện':
              simulatedSentiment = 0.2;
              break;
            default:
              simulatedSentiment = -0.1;
          }
          
          memberSentiments[member]!.add(simulatedSentiment);
        }
      }
      
      // Calculate overall mood
      double overallMood = 0.0;
      if (allMessages.isNotEmpty) {
        overallMood = allMessages
            .map((msg) => msg.sentiment.score)
            .reduce((a, b) => a + b) / allMessages.length;
      }
      
      // Find stressed members
      List<StressedMember> stressedMembers = [];
      memberSentiments.forEach((member, sentiments) {
        if (sentiments.isNotEmpty) {
          final avgSentiment = sentiments.reduce((a, b) => a + b) / sentiments.length;
          final stressLevel = (-avgSentiment).clamp(0.0, 1.0);
          
          if (stressLevel > 0.6) {
            stressedMembers.add(StressedMember(
              email: member,
              stressLevel: stressLevel,
              riskFactors: _generateRiskFactors(stressLevel, sentiments),
            ));
          }
        }
      });
      
      return TeamMoodAnalysis(
        projectId: projectId,
        overallMood: overallMood,
        moodLabel: _getMoodLabel(overallMood),
        memberCount: memberSentiments.keys.length,
        stressedMembers: stressedMembers,
        analysisDate: DateTime.now(),
        confidence: _calculateConfidence(allMessages.length),
        recommendations: _generateRecommendations(overallMood, stressedMembers),
        trendDirection: _calculateTrendDirection(allMessages),
      );
      
    } catch (e) {
      print('Error analyzing team mood: $e');
      return TeamMoodAnalysis.empty(projectId);
    }
  }
  
  /// Lấy mood label từ score
  static String _getMoodLabel(double mood) {
    if (mood > 0.5) return 'Rất tích cực 😊';
    if (mood > 0.2) return 'Tích cực 👍';
    if (mood > -0.2) return 'Bình thường 😐';
    if (mood > -0.5) return 'Tiêu cực 😕';
    return 'Rất tiêu cực 😰';
  }
  
  /// Generate risk factors for stressed members
  static List<String> _generateRiskFactors(double stressLevel, List<double> sentiments) {
    List<String> factors = [];
    
    if (stressLevel > 0.8) {
      factors.add('Mức stress cực cao');
    } else if (stressLevel > 0.6) {
      factors.add('Mức stress cao');
    }
    
    // Check for declining trend
    if (sentiments.length >= 3) {
      final recent = sentiments.sublist(sentiments.length - 3);
      if (recent.every((s) => s < -0.3)) {
        factors.add('Xu hướng tiêu cực liên tục');
      }
    }
    
    return factors;
  }
  
  /// Generate recommendations based on analysis
  static List<String> _generateRecommendations(double overallMood, List<StressedMember> stressedMembers) {
    List<String> recommendations = [];
    
    if (overallMood < -0.3) {
      recommendations.add('🎯 Tổ chức team building để cải thiện tinh thần');
      recommendations.add('📅 Review workload và deadline của team');
    }
    
    if (stressedMembers.isNotEmpty) {
      recommendations.add('⚠️ Check-in cá nhân với ${stressedMembers.length} thành viên có dấu hiệu stress');
      recommendations.add('🔄 Cân nhắc phân bổ lại công việc');
    }
    
    if (overallMood > 0.3) {
      recommendations.add('🎉 Team đang có tinh thần tốt, duy trì momentum này!');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('📊 Tiếp tục monitor mood của team');
    }
    
    return recommendations;
  }
  
  /// Calculate trend direction
  static String _calculateTrendDirection(List<MessageSentiment> messages) {
    if (messages.length < 2) return 'stable';
    
    final recent = messages.where((msg) => 
      msg.timestamp.isAfter(DateTime.now().subtract(Duration(days: 3)))
    ).toList();
    
    final older = messages.where((msg) => 
      msg.timestamp.isBefore(DateTime.now().subtract(Duration(days: 3)))
    ).toList();
    
    if (recent.isEmpty || older.isEmpty) return 'stable';
    
    final recentAvg = recent.map((m) => m.sentiment.score).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((m) => m.sentiment.score).reduce((a, b) => a + b) / older.length;
    
    final diff = recentAvg - olderAvg;
    
    if (diff > 0.2) return 'improving';
    if (diff < -0.2) return 'declining';
    return 'stable';
  }
  
  /// Calculate confidence level
  static double _calculateConfidence(int messageCount) {
    if (messageCount == 0) return 0.0;
    if (messageCount < 5) return 0.3;
    if (messageCount < 10) return 0.6;
    if (messageCount < 20) return 0.8;
    return 0.9;
  }
  
  /// Save mood analysis to Firebase
  static Future<void> saveMoodAnalysis(TeamMoodAnalysis analysis) async {
    try {
      await _firestore
          .collection('TeamMoodAnalysis')
          .doc(analysis.projectId)
          .collection('dailyAnalysis')
          .doc(DateTime.now().toIso8601String().split('T')[0])
          .set(analysis.toJson());
    } catch (e) {
      print('Error saving mood analysis: $e');
    }
  }
  
  /// Get mood history for charts
  static Future<List<TeamMoodAnalysis>> getMoodHistory(String projectId, {int days = 30}) async {
    try {
      final snapshot = await _firestore
          .collection('TeamMoodAnalysis')
          .doc(projectId)
          .collection('dailyAnalysis')
          .orderBy('analysisDate', descending: true)
          .limit(days)
          .get();
      
      return snapshot.docs
          .map((doc) => TeamMoodAnalysis.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting mood history: $e');
      return [];
    }
  }
}

/// Sentiment result model
class SentimentResult {
  final double score; // -1.0 to 1.0
  final double magnitude; // 0.0 to 1.0
  final String label; // positive, negative, neutral
  
  SentimentResult({
    required this.score,
    required this.magnitude,
    required this.label,
  });
  
  Map<String, dynamic> toJson() => {
    'score': score,
    'magnitude': magnitude,
    'label': label,
  };
  
  static SentimentResult fromJson(Map<String, dynamic> json) => SentimentResult(
    score: json['score']?.toDouble() ?? 0.0,
    magnitude: json['magnitude']?.toDouble() ?? 0.0,
    label: json['label'] ?? 'neutral',
  );
}

/// Team mood analysis result
class TeamMoodAnalysis {
  final String projectId;
  final double overallMood;
  final String moodLabel;
  final int memberCount;
  final List<StressedMember> stressedMembers;
  final DateTime analysisDate;
  final double confidence;
  final List<String> recommendations;
  final String trendDirection;
  
  TeamMoodAnalysis({
    required this.projectId,
    required this.overallMood,
    required this.moodLabel,
    required this.memberCount,
    required this.stressedMembers,
    required this.analysisDate,
    required this.confidence,
    required this.recommendations,
    required this.trendDirection,
  });
  
  factory TeamMoodAnalysis.empty(String projectId) => TeamMoodAnalysis(
    projectId: projectId,
    overallMood: 0.0,
    moodLabel: 'Không có dữ liệu',
    memberCount: 0,
    stressedMembers: [],
    analysisDate: DateTime.now(),
    confidence: 0.0,
    recommendations: ['Chưa có đủ dữ liệu để phân tích'],
    trendDirection: 'stable',
  );
  
  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'overallMood': overallMood,
    'moodLabel': moodLabel,
    'memberCount': memberCount,
    'stressedMembers': stressedMembers.map((m) => m.toJson()).toList(),
    'analysisDate': analysisDate.toIso8601String(),
    'confidence': confidence,
    'recommendations': recommendations,
    'trendDirection': trendDirection,
  };
  
  static TeamMoodAnalysis fromJson(Map<String, dynamic> json) => TeamMoodAnalysis(
    projectId: json['projectId'] ?? '',
    overallMood: json['overallMood']?.toDouble() ?? 0.0,
    moodLabel: json['moodLabel'] ?? '',
    memberCount: json['memberCount'] ?? 0,
    stressedMembers: (json['stressedMembers'] as List?)
        ?.map((m) => StressedMember.fromJson(m))
        .toList() ?? [],
    analysisDate: DateTime.tryParse(json['analysisDate'] ?? '') ?? DateTime.now(),
    confidence: json['confidence']?.toDouble() ?? 0.0,
    recommendations: List<String>.from(json['recommendations'] ?? []),
    trendDirection: json['trendDirection'] ?? 'stable',
  );
}

/// Stressed member model
class StressedMember {
  final String email;
  final double stressLevel;
  final List<String> riskFactors;
  
  StressedMember({
    required this.email,
    required this.stressLevel,
    required this.riskFactors,
  });
  
  Map<String, dynamic> toJson() => {
    'email': email,
    'stressLevel': stressLevel,
    'riskFactors': riskFactors,
  };
  
  static StressedMember fromJson(Map<String, dynamic> json) => StressedMember(
    email: json['email'] ?? '',
    stressLevel: json['stressLevel']?.toDouble() ?? 0.0,
    riskFactors: List<String>.from(json['riskFactors'] ?? []),
  );
}

/// Message sentiment model
class MessageSentiment {
  final String text;
  final SentimentResult sentiment;
  final String author;
  final DateTime timestamp;
  
  MessageSentiment({
    required this.text,
    required this.sentiment,
    required this.author,
    required this.timestamp,
  });
} 