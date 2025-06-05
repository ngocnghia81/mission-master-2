abstract class TaskEvents {}

class AddTasks extends TaskEvents {
  String taskName;
  String taskDescription;
  String deadlineDate;
  String deadlineTime;
  List<String> member;
  String priority;
  bool isRecurring;
  String recurringInterval;
  
  AddTasks({
      required this.taskName,
      required this.taskDescription,
      required this.deadlineDate,
      required this.deadlineTime,
      required this.member,
      this.priority = 'normal',
      this.isRecurring = false,
      this.recurringInterval = ''});
}
