import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:intl/intl.dart';

class BudgetManagementScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const BudgetManagementScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _BudgetManagementScreenState createState() => _BudgetManagementScreenState();
}

class _BudgetManagementScreenState extends State<BudgetManagementScreen> {
  final ResourceRepository _repository = ResourceRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  List<BudgetItem> _budgetItems = [];
  List<BudgetCategory> _categories = [];
  String _selectedCategory = 'development';
  bool _isLoading = true;
  double _totalBudget = 0;
  double _totalSpent = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeCategories();
    _loadBudgetData();
  }

  void _initializeCategories() {
    _categories = [
      BudgetCategory(id: 'development', name: 'Phát triển', icon: Icons.code),
      BudgetCategory(id: 'design', name: 'Thiết kế', icon: Icons.design_services),
      BudgetCategory(id: 'testing', name: 'Kiểm thử', icon: Icons.bug_report),
      BudgetCategory(id: 'equipment', name: 'Thiết bị', icon: Icons.computer),
      BudgetCategory(id: 'marketing', name: 'Marketing', icon: Icons.campaign),
      BudgetCategory(id: 'other', name: 'Khác', icon: Icons.more_horiz),
    ];
  }

  Future<void> _loadBudgetData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _repository.getBudgetItems(widget.projectId);
      setState(() {
        _budgetItems = items;
        _calculateTotals();
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Không thể tải dữ liệu ngân sách: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateTotals() {
    _totalBudget = _budgetItems.fold(0, (sum, item) => sum + item.allocatedAmount);
    _totalSpent = _budgetItems.fold(0, (sum, item) => sum + item.spentAmount);
  }

  Future<void> _addBudgetItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newItem = BudgetItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        projectId: widget.projectId,
        category: _selectedCategory,
        title: _titleController.text,
        description: _descriptionController.text,
        allocatedAmount: double.tryParse(_amountController.text) ?? 0.0,
        spentAmount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _repository.addBudgetItem(newItem);
      
      if (result != null) {
        _showSuccessSnackBar('Đã thêm khoản ngân sách thành công');
        _clearForm();
        await _loadBudgetData();
      } else {
        _showErrorSnackBar('Không thể thêm khoản ngân sách');
      }
    } catch (e) {
      _showErrorSnackBar('Không thể thêm khoản ngân sách: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBudgetItem(BudgetItem item) async {
    await showDialog(
      context: context,
      builder: (context) => _BuildEditBudgetDialog(
        item: item,
        categories: _categories,
        onSave: (updatedItem) async {
          setState(() {
            _isLoading = true;
          });

          try {
            await _repository.updateBudgetItem(updatedItem);
            _showSuccessSnackBar('Đã cập nhật khoản ngân sách thành công');
            await _loadBudgetData();
          } catch (e) {
            _showErrorSnackBar('Không thể cập nhật khoản ngân sách: $e');
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  Future<void> _deleteBudgetItem(BudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa khoản ngân sách "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _repository.deleteBudgetItem(item.id);
        _showSuccessSnackBar('Đã xóa khoản ngân sách thành công');
        await _loadBudgetData();
      } catch (e) {
        _showErrorSnackBar('Không thể xóa khoản ngân sách: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = 'development';
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Ngân sách'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  SizedBox(height: 20),
                  _buildCategoryBreakdown(),
                  SizedBox(height: 20),
                  _buildResourceBudgetGuide(),
                  SizedBox(height: 20),
                  _buildAddBudgetForm(),
                  SizedBox(height: 20),
                  _buildBudgetList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final remaining = _totalBudget - _totalSpent;
    final spentPercentage = _totalBudget > 0 ? (_totalSpent / _totalBudget) * 100 : 0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tổng quan Ngân sách',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.sync, color: AppColors.primary),
                  onPressed: _syncWithMainBudget,
                  tooltip: 'Đồng bộ với hệ thống ngân sách chính',
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Tổng ngân sách',
                    _formatCurrency(_totalBudget),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Đã sử dụng',
                    _formatCurrency(_totalSpent),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Còn lại',
                    _formatCurrency(remaining),
                    remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Tỷ lệ sử dụng',
                    '${spentPercentage.toStringAsFixed(1)}%',
                    _getPercentageColor(spentPercentage.toDouble()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: _totalBudget > 0 ? _totalSpent / _totalBudget : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getPercentageColor(spentPercentage.toDouble()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncWithMainBudget() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Đồng bộ ngân sách với hệ thống chính
      final success = await _repository.syncBudgetWithItems(widget.projectId);
      
      if (success) {
        _showSuccessSnackBar('Đã đồng bộ ngân sách thành công với hệ thống chính');
      } else {
        _showErrorSnackBar('Không thể đồng bộ ngân sách');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi khi đồng bộ ngân sách: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final categoryTotals = <String, double>{};
    for (final item in _budgetItems) {
      categoryTotals[item.category] = (categoryTotals[item.category] ?? 0.0) + item.allocatedAmount;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phân bổ theo danh mục',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...categoryTotals.entries.map((entry) {
              final category = _categories.firstWhere((c) => c.id == entry.key);
              final percentage = _totalBudget > 0 ? (entry.value / _totalBudget) * 100 : 0.0;
              
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(category.icon, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(category.name),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatCurrency(entry.value),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceBudgetGuide() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue[700]),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Hướng dẫn sử dụng ngân sách cho tài nguyên',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildGuideExample(
              'Ví dụ thực tế:',
              '1. Tạo budget "Thiết bị" - 50M VND\n'
              '2. Thêm tài nguyên "MacBook Pro" - 25M VND/cái\n'
              '3. Phân bổ 2 cái MacBook cho task\n'
              '4. Tự động trừ 50M VND từ ngân sách',
            ),
            SizedBox(height: 12),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToResourceManagement(),
                    icon: Icon(Icons.inventory_2, size: 18),
                    label: Text('Quản lý Tài nguyên'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showBudgetResourceDemo(),
                    icon: Icon(Icons.play_circle, size: 18),
                    label: Text('Xem Demo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideExample(String title, String content) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Future<void> _showBudgetResourceDemo() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Demo: Quy trình Ngân sách → Tài nguyên'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDemoStep(
                  '1',
                  'Tạo Khoản Ngân sách',
                  'Laptop Development: 100,000,000 VND',
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
                _buildDemoStep(
                  '2',
                  'Thêm Tài nguyên',
                  'MacBook Pro M3: 50,000,000 VND/cái\nĐộ Developer: 1,000,000 VND/ngày',
                  Icons.laptop_mac,
                  Colors.green,
                ),
                _buildDemoStep(
                  '3',
                  'Tạo Task',
                  'Task: "Phát triển Mobile App"\nThời gian: 10 ngày',
                  Icons.task,
                  Colors.orange,
                ),
                _buildDemoStep(
                  '4',
                  'Phân bổ Tài nguyên',
                  '• 1x MacBook Pro (50M VND)\n• 1x Developer x 10 ngày (10M VND)\nTổng chi phí: 60M VND',
                  Icons.assignment,
                  Colors.purple,
                ),
                _buildDemoStep(
                  '5',
                  'Cập nhật Ngân sách',
                  'Laptop Development:\n• Phân bổ: 100M VND\n• Đã dùng: 60M VND\n• Còn lại: 40M VND',
                  Icons.trending_down,
                  Colors.red,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToResourceManagement();
            },
            child: Text('Thực hành ngay'),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoStep(String step, String title, String description, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    SizedBox(width: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBudgetForm() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thêm khoản ngân sách mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 20),
                        SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên khoản mục',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên khoản mục';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Số tiền (VND)',
                  border: OutlineInputBorder(),
                  prefixText: '₫ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addBudgetItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Thêm khoản ngân sách',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetList() {
    if (_budgetItems.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Chưa có khoản ngân sách nào',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh sách khoản ngân sách',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showResourceAllocationDialog,
                    icon: Icon(Icons.inventory_2, size: 18),
                    label: Text('Phân bổ cho tài nguyên'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...(_budgetItems.map((item) => _buildBudgetItemCard(item)).toList()),
          ],
        ),
      ),
    );
  }

  Future<void> _showResourceAllocationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phân bổ ngân sách cho tài nguyên'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cách sử dụng ngân sách cho tài nguyên:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildInstructionStep(
                '1',
                'Tạo khoản mục ngân sách',
                'Thêm các khoản mục với số tiền cụ thể (VD: Laptop - 20,000,000 VND)',
              ),
              _buildInstructionStep(
                '2',
                'Quản lý tài nguyên',
                'Vào "Quản lý tài nguyên" → Thêm tài nguyên với chi phí/đơn vị',
              ),
              _buildInstructionStep(
                '3',
                'Phân bổ tài nguyên',
                'Khi tạo task → Phân bổ tài nguyên → Chi phí tự động trừ vào ngân sách',
              ),
              _buildInstructionStep(
                '4',
                'Theo dõi chi tiêu',
                'Cập nhật "Số tiền đã sử dụng" để theo dõi thực tế',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToResourceManagement();
            },
            child: Text('Đi đến Quản lý tài nguyên'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToResourceManagement() {
    Navigator.pushNamed(
      context,
      AppRoutes.resourceManagement,
      arguments: {
        'projectId': widget.projectId,
      },
    );
  }

  Widget _buildBudgetItemCard(BudgetItem item) {
    final category = _categories.firstWhere((c) => c.id == item.category);
    final spentPercentage = item.allocatedAmount > 0 ? (item.spentAmount / item.allocatedAmount) * 100 : 0;
    final remaining = item.allocatedAmount - item.spentAmount;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _updateBudgetItem(item);
                  } else if (value == 'delete') {
                    _deleteBudgetItem(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngân sách: ${_formatCurrency(item.allocatedAmount)}',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                    Text(
                      'Đã dùng: ${_formatCurrency(item.spentAmount)}',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                    Text(
                      'Còn lại: ${_formatCurrency(remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: remaining >= 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${spentPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getPercentageColor(spentPercentage.toDouble()),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: item.allocatedAmount > 0 ? item.spentAmount / item.allocatedAmount : 0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getPercentageColor(spentPercentage.toDouble()),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.orange;
    return Colors.red;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} ₫';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _BuildEditBudgetDialog extends StatefulWidget {
  final BudgetItem item;
  final List<BudgetCategory> categories;
  final Function(BudgetItem) onSave;

  const _BuildEditBudgetDialog({
    required this.item,
    required this.categories,
    required this.onSave,
  });

  @override
  _BuildEditBudgetDialogState createState() => _BuildEditBudgetDialogState();
}

class _BuildEditBudgetDialogState extends State<_BuildEditBudgetDialog> {
  late TextEditingController _titleController;
  late TextEditingController _allocatedController;
  late TextEditingController _spentController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _allocatedController = TextEditingController(text: widget.item.allocatedAmount.toString());
    _spentController = TextEditingController(text: widget.item.spentAmount.toString());
    _descriptionController = TextEditingController(text: widget.item.description);
    _selectedCategory = widget.item.category;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chỉnh sửa ngân sách'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCategory,
                items: widget.categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 20),
                        SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên khoản mục',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên khoản mục';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _allocatedController,
                decoration: InputDecoration(
                  labelText: 'Ngân sách phân bổ (VND)',
                  border: OutlineInputBorder(),
                  prefixText: '₫ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _spentController,
                decoration: InputDecoration(
                  labelText: 'Số tiền đã sử dụng (VND)',
                  border: OutlineInputBorder(),
                  prefixText: '₫ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số tiền đã sử dụng';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedItem = BudgetItem(
                id: widget.item.id,
                projectId: widget.item.projectId,
                category: _selectedCategory,
                title: _titleController.text,
                description: _descriptionController.text,
                allocatedAmount: double.tryParse(_allocatedController.text) ?? 0.0,
                spentAmount: double.tryParse(_spentController.text) ?? 0.0,
                createdAt: widget.item.createdAt,
                updatedAt: DateTime.now(),
              );
              widget.onSave(updatedItem);
              Navigator.pop(context);
            }
          },
          child: Text('Lưu'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _allocatedController.dispose();
    _spentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class BudgetCategory {
  final String id;
  final String name;
  final IconData icon;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
} 