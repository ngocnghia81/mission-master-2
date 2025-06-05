import 'package:get_it/get_it.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/notification/notification_services.dart';

GetIt locator = GetIt.instance;
void setup() {
  locator.registerSingleton(Database());
  locator.registerSingleton(NotificationServices());
  // locator.registerFactory<Database>(() => Database());
}
