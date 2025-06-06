import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';

class ResourceAllocationScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ResourceAllocationScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _ResourceAllocationScreenState createState() => _ResourceAllocationScreenState();
}

class _ResourceAllocationScreenState extends State<ResourceAllocationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phân bổ Tài nguyên'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            SizedBox(height: 24),
            _buildInstructionCard(),
            SizedBox(height: 24),
            _buildExampleCard(),
            SizedBox(height: 24),
            _buildBenefitsCard(),
            SizedBox(height: 24),
            _buildImplementationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_ind, size: 32, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân bổ Tài nguyên cho Tasks',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      Text(
                        'Dự án: ${widget.projectName}',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Phân bổ tài nguyên cho tasks/milestones là quá trình gán các tài nguyên cụ thể (nhân lực, thiết bị, vật liệu) cho từng nhiệm vụ trong dự án.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quy trình Phân bổ Tài nguyên:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildStep('1', 'Tạo Tài nguyên', 'Thêm các loại tài nguyên cần thiết (Developer, Designer, Laptop, etc.)', Icons.add_box),
            _buildStep('2', 'Tạo Tasks', 'Chia nhỏ dự án thành các tasks/milestones cụ thể', Icons.task_alt),
            _buildStep('3', 'Gán tài nguyên', 'Chọn tài nguyên phù hợp cho từng task', Icons.person_add),
            _buildStep('4', 'Thiết lập thời gian', 'Xác định thời gian bắt đầu và kết thúc sử dụng', Icons.schedule),
            _buildStep('5', 'Theo dõi tiến độ', 'Monitor tình trạng sử dụng và hiệu suất', Icons.analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 16),
          Icon(icon, color: AppColors.primary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], height: 1.4),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ví dụ thực tế:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildExampleItem('📱 Task: "Thiết kế giao diện Login"', 'Tài nguyên: 1 UI/UX Designer', 'Thời gian: 3 ngày', '💰 Chi phí: 2,250,000 VND'),
            _buildExampleItem('⚙️ Task: "API Authentication"', 'Tài nguyên: 1 Backend Developer', 'Thời gian: 5 ngày', '💰 Chi phí: 6,250,000 VND'),
            _buildExampleItem('🧪 Task: "Testing Login Feature"', 'Tài nguyên: 1 Tester + 1 Thiết bị test', 'Thời gian: 2 ngày', '💰 Chi phí: 1,500,000 VND'),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleItem(String task, String resource, String time, String cost) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task, 
            style: TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          SizedBox(height: 4),
          Text(
            '🔧 $resource', 
            style: TextStyle(color: Colors.blue[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          Text(
            '⏱️ $time', 
            style: TextStyle(color: Colors.green[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            cost, 
            style: TextStyle(color: Colors.purple[700]),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lợi ích của việc Phân bổ Tài nguyên:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildBenefitItem('📊 Theo dõi chi phí chính xác', 'Biết rõ chi phí cho từng task'),
            _buildBenefitItem('⚡ Tối ưu hóa hiệu suất', 'Tránh lãng phí và over-allocation'),
            _buildBenefitItem('📅 Quản lý thời gian tốt hơn', 'Lập kế hoạch timeline chi tiết'),
            _buildBenefitItem('🔍 Phát hiện bottleneck', 'Nhận biết tài nguyên thiếu hụt'),
            _buildBenefitItem('📈 Báo cáo minh bạch', 'Dashboard và analytics rõ ràng'),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String title, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                Text(
                  description, 
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImplementationCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.construction, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tính năng đang phát triển:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple[800]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚧 Tính năng phân bổ tài nguyên chi tiết đang được phát triển',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.purple[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hiện tại bạn có thể:',
                    style: TextStyle(color: Colors.purple[700]),
                  ),
                  SizedBox(height: 8),
                  _buildCurrentFeature('✅ Tạo và quản lý tài nguyên'),
                  _buildCurrentFeature('✅ Thiết lập ngân sách dự án'),
                  _buildCurrentFeature('✅ Theo dõi chi phí theo danh mục'),
                  _buildCurrentFeature('✅ Tạo và phân công tasks'),
                  SizedBox(height: 8),
                  Text(
                    'Sắp ra mắt:',
                    style: TextStyle(color: Colors.purple[700]),
                  ),
                  SizedBox(height: 8),
                  _buildUpcomingFeature('🔜 Gán tài nguyên trực tiếp cho task'),
                  _buildUpcomingFeature('🔜 Timeline allocation calendar'),
                  _buildUpcomingFeature('🔜 Resource conflict detection'),
                  _buildUpcomingFeature('🔜 Automatic cost calculation'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentFeature(String feature) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        feature,
        style: TextStyle(color: Colors.purple[600], fontSize: 14),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _buildUpcomingFeature(String feature) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Text(
        feature,
        style: TextStyle(color: Colors.purple[600], fontSize: 14),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
} 