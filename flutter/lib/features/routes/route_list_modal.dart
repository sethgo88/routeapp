import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/saved_route.dart';
import '../../services/db.dart' as db;

/// Shared provider for the list of saved routes.
/// Invalidate this provider after any create / update / delete operation.
final savedRoutesProvider =
    FutureProvider<List<SavedRoute>>((ref) => db.listRoutes());
