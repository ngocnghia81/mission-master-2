import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enterprise_project_model.dart';

class EnterpriseProjectRepository {
  static const String _collectionName = 'EnterpriseProjects';
  
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;
  
  EnterpriseProjectRepository(this._prefs, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Create a new project
  Future<String> createProject(EnterpriseProject project) async {
    try {
      await _firestore.collection(_collectionName).doc(project.id).set(project.toMap());
      return project.id;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  // Read a project by ID
  Future<EnterpriseProject?> getProject(String projectId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(projectId).get();
      
      if (!doc.exists || doc.data() == null) return null;
      
      final data = doc.data()!;
      data['id'] = doc.id; // Ensure ID is included
      return EnterpriseProject.fromMap(data);
    } catch (e) {
      throw Exception('Failed to get project: $e');
    }
  }

  // Read all projects
  Future<List<EnterpriseProject>> getAllProjects() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final projects = <EnterpriseProject>[];
      
      for (final doc in snapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = doc.data();
          data['id'] = doc.id; // Ensure ID is included
          projects.add(EnterpriseProject.fromMap(data));
        }
      }
      
      // Sort by creation date (newest first)
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return projects;
    } catch (e) {
      throw Exception('Failed to get all projects: $e');
    }
  }

  // Update a project
  Future<bool> updateProject(EnterpriseProject project) async {
    try {
      await _firestore.collection(_collectionName).doc(project.id).update(project.toMap());
      return true;
    } catch (e) {
      throw Exception('Failed to update project: $e');
    }
  }

  // Delete a project
  Future<bool> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
      return true;
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  // Get projects by status
  Future<List<EnterpriseProject>> getProjectsByStatus(String status) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: status)
          .get();
      
      final projects = <EnterpriseProject>[];
      for (final doc in snapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = doc.data();
          data['id'] = doc.id;
          projects.add(EnterpriseProject.fromMap(data));
        }
      }
      
      return projects;
    } catch (e) {
      throw Exception('Failed to get projects by status: $e');
    }
  }

  // Get projects by type
  Future<List<EnterpriseProject>> getProjectsByType(String type) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('type', isEqualTo: type)
          .get();
      
      final projects = <EnterpriseProject>[];
      for (final doc in snapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = doc.data();
          data['id'] = doc.id;
          projects.add(EnterpriseProject.fromMap(data));
        }
      }
      
      return projects;
    } catch (e) {
      throw Exception('Failed to get projects by type: $e');
    }
  }

  // Get projects by member email
  Future<List<EnterpriseProject>> getProjectsByMember(String memberEmail) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('memberEmails', arrayContains: memberEmail)
          .get();
      
      final projects = <EnterpriseProject>[];
      for (final doc in snapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = doc.data();
          data['id'] = doc.id;
          projects.add(EnterpriseProject.fromMap(data));
        }
      }
      
      return projects;
    } catch (e) {
      throw Exception('Failed to get projects by member: $e');
    }
  }

  // Get overdue projects
  Future<List<EnterpriseProject>> getOverdueProjects() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('endDate', isLessThan: Timestamp.fromDate(DateTime.now()))
          .where('status', isNotEqualTo: 'completed')
          .get();
      
      final projects = <EnterpriseProject>[];
      for (final doc in snapshot.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = doc.data();
          data['id'] = doc.id;
          projects.add(EnterpriseProject.fromMap(data));
        }
      }
      
      return projects;
    } catch (e) {
      throw Exception('Failed to get overdue projects: $e');
    }
  }

  // Search projects by name or description
  Future<List<EnterpriseProject>> searchProjects(String query) async {
    try {
      final allProjects = await getAllProjects();
      final lowercaseQuery = query.toLowerCase();
      
      return allProjects.where((project) =>
        project.name.toLowerCase().contains(lowercaseQuery) ||
        project.description.toLowerCase().contains(lowercaseQuery)
      ).toList();
    } catch (e) {
      throw Exception('Failed to search projects: $e');
    }
  }

  // Get project statistics
  Future<Map<String, int>> getProjectStatistics() async {
    try {
      final allProjects = await getAllProjects();
      
      final stats = <String, int>{
        'total': allProjects.length,
        'planning': 0,
        'active': 0,
        'on_hold': 0,
        'completed': 0,
        'cancelled': 0,
        'overdue': 0,
      };
      
      for (final project in allProjects) {
        stats[project.status] = (stats[project.status] ?? 0) + 1;
        if (project.isOverdue) {
          stats['overdue'] = (stats['overdue'] ?? 0) + 1;
        }
      }
      
      return stats;
    } catch (e) {
      throw Exception('Failed to get project statistics: $e');
    }
  }

  // Clear all projects
  Future<void> clearAllProjects() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      
      // Delete all documents
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear all projects: $e');
    }
  }

  // Export projects data (for backup)
  Future<Map<String, dynamic>> exportProjectsData() async {
    try {
      final allProjects = await getAllProjects();
      final projectsData = allProjects.map((project) => project.toMap()).toList();
      
      return {
        'projects': projectsData,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
      };
    } catch (e) {
      throw Exception('Failed to export projects data: $e');
    }
  }

  // Import projects data (for restore)
  Future<bool> importProjectsData(Map<String, dynamic> data) async {
    try {
      final projectsData = data['projects'] as List<dynamic>;
      
      final batch = _firestore.batch();
      for (final projectData in projectsData) {
        final project = EnterpriseProject.fromMap(projectData as Map<String, dynamic>);
        final docRef = _firestore.collection(_collectionName).doc(project.id);
        batch.set(docRef, project.toMap());
      }
      await batch.commit();
      
      return true;
    } catch (e) {
      throw Exception('Failed to import projects data: $e');
    }
  }

  // Get project members (for task assignment)
  Future<List<String>> getProjectMembers(String projectId) async {
    try {
      final project = await getProject(projectId);
      return project?.memberEmails ?? [];
    } catch (e) {
      print('Error getting project members: $e');
      return [];
    }
  }
} 