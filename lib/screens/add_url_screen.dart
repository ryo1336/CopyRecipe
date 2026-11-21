import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_exception.dart';
import '../providers/recipes_provider.dart';

class AddUrlScreen extends ConsumerStatefulWidget {
  /// 登録が終わったときに呼ぶ。1本だけ登録した場合はその動画 ID を渡す
  final void Function(String? singleVideoId)? onAdded;

  const AddUrlScreen({super.key, this.onAdded});

  @override
  ConsumerState<AddUrlScreen> createState() => _AddUrlScreenState();
}

class _AddUrlScreenState extends ConsumerState<AddUrlScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addRecipe() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final result = await ref.read(recipesProvider.notifier).addFromUrl(url);
      if (mounted) {
        _urlController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        widget.onAdded?.call(result.singleVideoId);
      }
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('予期しないエラーが発生しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'YouTubeの動画または再生リストのURLを入力',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            onSubmitted: (_) => _addRecipe(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addRecipe,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('追加'),
            ),
          ),
        ],
      ),
    );
  }
}
