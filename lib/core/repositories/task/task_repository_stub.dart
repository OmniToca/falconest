/// Stub repozitáře pro platformy, kde ani web ani io nejsou k dispozici.
///
/// Volání getTaskRepository() vyhodí výjimku. Používá se jako fallback
/// při podmíněném importu (např. při testech bez platformy).
library;
import 'package:falconest/core/repositories/task/task_repository.dart';

ITaskRepository getTaskRepository() =>
    throw UnsupportedError('TaskRepository není dostupný na této platformě.');
