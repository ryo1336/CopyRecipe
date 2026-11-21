import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_exception.dart';
import '../providers/recipes_provider.dart';

/// URL を入力してレシピを追加するシートを開く。
///
/// 登録できたらシートを閉じ、1本だけ登録した場合はその動画 ID を返す
Future<String?> showAddRecipeSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddRecipeSheet(),
    );

class AddRecipeSheet extends ConsumerStatefulWidget {
  const AddRecipeSheet({super.key});

  @override
  ConsumerState<AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends ConsumerState<AddRecipeSheet> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// YouTube アプリで「リンクをコピー」したあとに、ワンタップで入れられるようにする
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _urlController.text = text;
      _error = null;
    });
  }

  Future<void> _addRecipe() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'URL を入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref.read(recipesProvider.notifier).addFromUrl(url);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, result.singleVideoId);
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('予期しないエラーが発生しました');
    }
  }

  /// エラーはシートの中（入力欄の下）に出す。シートの裏に通知を出しても見えないため
  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // キーボードが出てもボタンが隠れないよう、その分だけ持ち上げる
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'レシピを追加',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'YouTube の動画または再生リストの URL を入れてください',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            autofocus: true,
            enabled: !_isLoading,
            // URL 用のキーボードにして、日本語入力の変換待ちにならないようにする
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            decoration: InputDecoration(
              hintText: 'https://youtu.be/...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: '貼り付け',
                onPressed: _isLoading ? null : _paste,
              ),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _addRecipe(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isLoading ? null : _addRecipe,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('追加する'),
          ),
        ],
      ),
    );
  }
}
