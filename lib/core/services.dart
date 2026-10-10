import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import 'db/database_flutter.dart';

/// 轻量依赖装配（不引入 riverpod，保持依赖最少）
class Services {
  Services._();

  static final CategoryRepository categories =
      CategoryRepository(db: AppDatabase.instance.database);

  static final TransactionRepository transactions =
      TransactionRepository(db: AppDatabase.instance.database);
}
