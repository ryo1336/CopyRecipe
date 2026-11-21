import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/recipes_provider.dart';

/// 概要欄のテキストを編集し、保存時に材料・工程を抽出し直す画面
///
/// Phase 3 で材料・工程を個別に編集する画面に置き換える予定。
class RawDescriptionEditScreen extends ConsumerStatefulWidget {
  const RawDescriptionEditScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<RawDescriptionEditScreen> createState() =>
      _RawDescriptionEditScreenState();
}

class _RawDescriptionEditScreenState extends ConsumerState<RawDescriptionEditScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final recipe = ref
        .read(recipesProvider)
        .where((r) => r.videoId == widget.videoId)
        .firstOrNull;
    _controller = TextEditingController(text: recipe?.rawDescription ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(recipesProvider.notifier)
        .updateDescription(widget.videoId, _controller.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Text('概要欄を編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          autofocus: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            helperText: '保存すると、材料と作り方を抽出し直します',
          ),
        ),
      ),
    );
  }
}
