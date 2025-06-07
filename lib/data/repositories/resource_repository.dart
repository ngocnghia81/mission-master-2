import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mission_master/data/models/resource_model.dart';

class ResourceRepository {
  final FirebaseFirestore _firestore;
  final String _resourceCollection = 'resources';
  final String _allocationCollection = 'resource_allocations';
  final String _budgetCollection = 'budgets';

  ResourceRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Phương thức quản lý tài nguyên
  Future<List<Resource>> getProjectResources(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_resourceCollection)
          .where('projectId', isEqualTo: projectId)
          .get();
      
      return snapshot.docs
          .map((doc) => Resource.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting project resources: $e');
      return [];
    }
  }

  Future<Resource?> getResourceById(String id) async {
    try {
      final doc = await _firestore.collection(_resourceCollection).doc(id).get();
      if (doc.exists) {
        return Resource.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting resource by ID: $e');
      return null;
    }
  }

  Future<String?> createResource(Resource resource) async {
    try {
      final docRef = await _firestore.collection(_resourceCollection).add({
        ...resource.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating resource: $e');
      return null;
    }
  }

  Future<bool> updateResource(Resource resource) async {
    try {
      await _firestore.collection(_resourceCollection).doc(resource.id).update({
        ...resource.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating resource: $e');
      return false;
    }
  }

  Future<bool> deleteResource(String id) async {
    try {
      // Kiểm tra xem tài nguyên có đang được sử dụng không
      final allocations = await _firestore
          .collection(_allocationCollection)
          .where('resourceId', isEqualTo: id)
          .limit(1)
          .get();
      
      if (allocations.docs.isNotEmpty) {
        print('Cannot delete resource: it is currently allocated');
        return false;
      }
      
      await _firestore.collection(_resourceCollection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting resource: $e');
      return false;
    }
  }

  // Phương thức quản lý phân bổ tài nguyên
  Future<List<ResourceAllocation>> getResourceAllocations(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_allocationCollection)
          .where('projectId', isEqualTo: projectId)
          .get();
      
      return snapshot.docs
          .map((doc) => ResourceAllocation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting resource allocations: $e');
      return [];
    }
  }

  Future<List<ResourceAllocation>> getTaskResourceAllocations(String taskId) async {
    try {
      final snapshot = await _firestore
          .collection(_allocationCollection)
          .where('taskId', isEqualTo: taskId)
          .get();
      
      return snapshot.docs
          .map((doc) => ResourceAllocation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting task resource allocations: $e');
      return [];
    }
  }

  Future<String?> allocateResource(ResourceAllocation allocation) async {
    try {
      // Kiểm tra xem tài nguyên có đủ đơn vị còn lại không
      final resource = await getResourceById(allocation.resourceId);
      if (resource == null || !resource.canAllocateMore(allocation.allocatedUnits)) {
        print('Cannot allocate resource: not enough available units');
        return null;
      }
      
      // Cập nhật số lượng đã phân bổ của tài nguyên
      await _firestore.collection(_resourceCollection).doc(allocation.resourceId).update({
        'allocatedUnits': FieldValue.increment(allocation.allocatedUnits),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Tạo bản ghi phân bổ mới
      final docRef = await _firestore.collection(_allocationCollection).add({
        ...allocation.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      print('Error allocating resource: $e');
      return null;
    }
  }

  Future<bool> updateAllocation(ResourceAllocation allocation, int previousUnits) async {
    try {
      // Tính toán sự thay đổi về số lượng đơn vị
      final unitsDifference = allocation.allocatedUnits - previousUnits;
      
      if (unitsDifference != 0) {
        // Kiểm tra xem tài nguyên có đủ đơn vị còn lại không (nếu cần thêm)
        if (unitsDifference > 0) {
          final resource = await getResourceById(allocation.resourceId);
          if (resource == null || !resource.canAllocateMore(unitsDifference)) {
            print('Cannot update allocation: not enough available units');
            return false;
          }
        }
        
        // Cập nhật số lượng đã phân bổ của tài nguyên
        await _firestore.collection(_resourceCollection).doc(allocation.resourceId).update({
          'allocatedUnits': FieldValue.increment(unitsDifference),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Cập nhật bản ghi phân bổ
      await _firestore.collection(_allocationCollection).doc(allocation.id).update({
        ...allocation.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error updating allocation: $e');
      return false;
    }
  }

  Future<bool> removeAllocation(String id) async {
    try {
      // Lấy thông tin phân bổ
      final doc = await _firestore.collection(_allocationCollection).doc(id).get();
      if (!doc.exists) return false;
      
      final allocation = ResourceAllocation.fromJson({...doc.data()!, 'id': doc.id});
      
      // Cập nhật số lượng đã phân bổ của tài nguyên
      await _firestore.collection(_resourceCollection).doc(allocation.resourceId).update({
        'allocatedUnits': FieldValue.increment(-allocation.allocatedUnits),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Xóa bản ghi phân bổ
      await _firestore.collection(_allocationCollection).doc(id).delete();
      
      return true;
    } catch (e) {
      print('Error removing allocation: $e');
      return false;
    }
  }

  // Phương thức quản lý ngân sách
  Future<Budget?> getProjectBudget(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_budgetCollection)
          .where('projectId', isEqualTo: projectId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        // Tạo ngân sách mặc định nếu chưa có
        final defaultBudget = Budget.createDefault(projectId);
        final docRef = await _firestore.collection(_budgetCollection).add({
          ...defaultBudget.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return Budget.fromJson({...defaultBudget.toJson(), 'id': docRef.id});
      }
      
      final doc = snapshot.docs.first;
      return Budget.fromJson({...doc.data(), 'id': doc.id});
    } catch (e) {
      print('Error getting project budget: $e');
      return null;
    }
  }

  Future<bool> updateBudget(Budget budget) async {
    try {
      await _firestore.collection(_budgetCollection).doc(budget.id).update({
        ...budget.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating budget: $e');
      return false;
    }
  }

  Future<bool> recordExpense(String budgetId, double amount, String category) async {
    try {
      // Lấy thông tin ngân sách hiện tại
      final doc = await _firestore.collection(_budgetCollection).doc(budgetId).get();
      if (!doc.exists) return false;
      
      final budget = Budget.fromJson({...doc.data()!, 'id': doc.id});
      
      // Kiểm tra xem có đủ ngân sách không
      if (!budget.canSpend(amount)) {
        print('Cannot record expense: not enough budget');
        return false;
      }
      
      // Cập nhật ngân sách
      final categoryAllocation = Map<String, dynamic>.from(budget.categoryAllocation);
      categoryAllocation[category] = (categoryAllocation[category] ?? 0.0) + amount;
      
      await _firestore.collection(_budgetCollection).doc(budgetId).update({
        'spentBudget': FieldValue.increment(amount),
        'categoryAllocation': categoryAllocation,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error recording expense: $e');
      return false;
    }
  }

  Future<String?> createBudget(Budget budget) async {
    try {
      final docRef = await _firestore.collection(_budgetCollection).add({
        ...budget.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating budget: $e');
      return null;
    }
  }

  // Phương thức quản lý budget items
  Future<List<BudgetItem>> getBudgetItems(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('budget_items')
          .where('projectId', isEqualTo: projectId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => BudgetItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting budget items: $e');
      return [];
    }
  }

  Future<String?> addBudgetItem(BudgetItem item) async {
    try {
      final docRef = await _firestore.collection('budget_items').add({
        ...item.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Đồng bộ Budget sau khi thêm BudgetItem
      await syncBudgetWithItems(item.projectId);
      
      return docRef.id;
    } catch (e) {
      print('Error adding budget item: $e');
      return null;
    }
  }

  Future<bool> updateBudgetItem(BudgetItem item) async {
    try {
      await _firestore.collection('budget_items').doc(item.id).update({
        ...item.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Đồng bộ Budget sau khi cập nhật BudgetItem
      await syncBudgetWithItems(item.projectId);
      
      return true;
    } catch (e) {
      print('Error updating budget item: $e');
      return false;
    }
  }

  Future<bool> deleteBudgetItem(String id) async {
    try {
      // Lấy thông tin item trước khi xóa để biết projectId
      final doc = await _firestore.collection('budget_items').doc(id).get();
      if (!doc.exists) return false;
      
      final item = BudgetItem.fromJson({...doc.data()!, 'id': doc.id});
      
      await _firestore.collection('budget_items').doc(id).delete();
      
      // Đồng bộ Budget sau khi xóa BudgetItem
      await syncBudgetWithItems(item.projectId);
      
      return true;
    } catch (e) {
      print('Error deleting budget item: $e');
      return false;
    }
  }

  // Phương thức tính chi phí và cập nhật ngân sách khi phân bổ tài nguyên
  Future<bool> allocateResourceAndUpdateBudget({
    required String projectId,
    required String resourceId,
    required String taskId,
    required int allocatedUnits,
    required String allocatedBy,
    required DateTime startDate,
    required DateTime endDate,
    String? budgetCategory,
  }) async {
    try {
      // 1. Lấy thông tin tài nguyên để tính chi phí
      final resource = await getResourceById(resourceId);
      if (resource == null) {
        print('Resource not found');
        return false;
      }

      // 2. Tính tổng chi phí
      final totalCost = resource.costPerUnit * allocatedUnits;
      print('Calculated cost: $totalCost for $allocatedUnits ${resource.costUnit}s');

      // 3. Tạo resource allocation
      final allocation = ResourceAllocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        resourceId: resourceId,
        taskId: taskId,
        projectId: projectId,
        allocatedUnits: allocatedUnits,
        startDate: startDate,
        endDate: endDate,
        allocatedBy: allocatedBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Thêm resource allocation
      final allocationResult = await allocateResource(allocation);
      if (allocationResult == null) {
        print('Failed to create resource allocation');
        return false;
      }

      // 5. Cập nhật budget item nếu có category được chỉ định
      if (budgetCategory != null) {
        await _updateBudgetItemSpending(projectId, budgetCategory, totalCost);
      }

      return true;
    } catch (e) {
      print('Error allocating resource and updating budget: $e');
      return false;
    }
  }

  // Cập nhật số tiền đã sử dụng của budget item
  Future<void> _updateBudgetItemSpending(String projectId, String category, double amount) async {
    try {
      // Tìm budget item phù hợp
      final budgetItems = await getBudgetItems(projectId);
      final targetBudgetItem = budgetItems.where((item) => item.category == category).firstOrNull;

      if (targetBudgetItem != null) {
        // Cập nhật số tiền đã sử dụng
        final updatedItem = BudgetItem(
          id: targetBudgetItem.id,
          projectId: targetBudgetItem.projectId,
          category: targetBudgetItem.category,
          title: targetBudgetItem.title,
          description: targetBudgetItem.description,
          allocatedAmount: targetBudgetItem.allocatedAmount,
          spentAmount: targetBudgetItem.spentAmount + amount,
          createdAt: targetBudgetItem.createdAt,
          updatedAt: DateTime.now(),
        );

        await updateBudgetItem(updatedItem);
        print('Updated budget item spending: +$amount VND for category $category');
      } else {
        print('No budget item found for category: $category');
      }
    } catch (e) {
      print('Error updating budget item spending: $e');
    }
  }

  // Lấy chi phí tài nguyên theo dự án
  Future<Map<String, double>> getResourceCostsByProject(String projectId) async {
    try {
      final allocations = await getResourceAllocations(projectId);
      final resources = await getProjectResources(projectId);
      
      Map<String, double> costsByCategory = {};
      
      for (var allocation in allocations) {
        final resource = resources.firstWhere(
          (r) => r.id == allocation.resourceId,
          orElse: () => resources.first,
        );
        
        final cost = resource.costPerUnit * allocation.allocatedUnits;
        final category = _getResourceCategory(resource.type);
        
        costsByCategory[category] = (costsByCategory[category] ?? 0.0) + cost;
      }
      
      return costsByCategory;
    } catch (e) {
      print('Error getting resource costs: $e');
      return {};
    }
  }

  String _getResourceCategory(String resourceType) {
    switch (resourceType.toLowerCase()) {
      case 'human':
        return 'development';
      case 'equipment':
        return 'equipment';
      case 'material':
        return 'other';
      default:
        return 'other';
    }
  }

  // Phương thức đồng bộ Budget và BudgetItems
  Future<bool> syncBudgetWithItems(String projectId) async {
    try {
      // Lấy tất cả BudgetItems của project
      final items = await getBudgetItems(projectId);
      
      // Tính tổng từ BudgetItems
      final totalFromItems = items.fold(0.0, (sum, item) => sum + item.allocatedAmount);
      final spentFromItems = items.fold(0.0, (sum, item) => sum + item.spentAmount);
      
      // Tính categoryAllocation từ BudgetItems
      final Map<String, double> categoryAllocation = {};
      for (var item in items) {
        final category = item.category;
        categoryAllocation[category] = (categoryAllocation[category] ?? 0.0) + item.allocatedAmount;
      }
      
      print('DEBUG: Sync budget - Total: $totalFromItems, Spent: $spentFromItems');
      print('DEBUG: Category allocation from items: $categoryAllocation');
      
      // Lấy Budget hiện tại
      final budget = await getProjectBudget(projectId);
      if (budget == null) return false;
      
      // Cập nhật Budget với dữ liệu từ BudgetItems
      final updatedBudget = budget.copyWith(
        totalBudget: totalFromItems,
        spentBudget: spentFromItems,
        allocatedBudget: totalFromItems, // Coi như đã phân bổ hết
        categoryAllocation: categoryAllocation, // Đồng bộ categoryAllocation
        updatedAt: DateTime.now(),
      );
      
      await updateBudget(updatedBudget);
      print('DEBUG: Budget synced successfully with categoryAllocation: ${updatedBudget.categoryAllocation}');
      return true;
    } catch (e) {
      print('Error syncing budget with items: $e');
      return false;
    }
  }
} 