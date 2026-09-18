import 'package:flutter/material.dart';

/// Obal pro deferred `loadLibrary()` – spinner dokud se nenačte chunk (typicky web HQ).
///
/// PROČ: Těžké Super Admin / wizard obrazovky nemusí být v hlavním bundle agentury.
/// [libraryLoader] je např. `superAdmin.loadLibrary`, [builder] vrací widget z deferred knihovny.
class DeferredPage extends StatefulWidget {
  const DeferredPage({
    super.key,
    required this.libraryLoader,
    required this.builder,
  });

  /// Volá se jednou – typicky `someDeferredLib.loadLibrary`.
  final Future<void> Function() libraryLoader;

  /// Staví cílovou obrazovku až po úspěšném loadLibrary.
  final WidgetBuilder builder;

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _loadFuture = widget.libraryLoader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
