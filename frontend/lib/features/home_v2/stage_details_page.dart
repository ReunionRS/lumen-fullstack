import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/ui_tokens.dart';
import '../../models/project_models.dart';
import '../../services/auth_service.dart';

class StageDetailsPage extends StatefulWidget {
  const StageDetailsPage({
    super.key,
    required this.projectId,
    required this.stageIndex,
    required this.initialStage,
    required this.auth,
    required this.role,
    required this.onUpdated,
  });

  final String projectId;
  final int stageIndex;
  final ProjectStage initialStage;
  final AuthService auth;
  final String role;
  final Future<void> Function() onUpdated;

  @override
  State<StageDetailsPage> createState() => _StageDetailsPageState();
}

class _StageDetailsPageState extends State<StageDetailsPage> {
  late ProjectStage _stage;
  late TextEditingController _commentController;
  bool _uploadingPhoto = false;
  bool _savingComment = false;
  bool _savingStatus = false;
  String _status = 'not_started';

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
    _commentController = TextEditingController(text: _stage.comments);
    _status = _stage.status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStage();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refreshStage() async {
    final updated = await widget.auth.fetchProjectById(widget.projectId);
    if (!mounted) return;
    if (updated.stages.length > widget.stageIndex) {
      setState(() {
        _stage = updated.stages[widget.stageIndex];
        _commentController.text = _stage.comments;
      });
    }
  }

  Future<void> _addStagePhotos() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(allowMultiple: true, type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      await widget.auth.uploadStagePhotos(
        projectId: widget.projectId,
        stageIndex: widget.stageIndex,
        files: result.files,
      );
      await widget.onUpdated();
      await _refreshStage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _saveStageComment() async {
    if (_savingComment) return;
    setState(() => _savingComment = true);
    try {
      final details = await widget.auth.fetchProjectById(widget.projectId);
      final updatedStages = [...details.stages];
      if (updatedStages.length > widget.stageIndex) {
        updatedStages[widget.stageIndex] =
            updatedStages[widget.stageIndex].copyWith(
          comments: _commentController.text.trim(),
        );
      }
      await widget.auth.updateProject(
        details.id,
        details.toPatchJson(stagesOverride: updatedStages),
      );
      await widget.onUpdated();
      await _refreshStage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Комментарий сохранён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _savingComment = false);
      }
    }
  }

  Future<void> _saveStageStatus() async {
    if (_savingStatus) return;
    setState(() => _savingStatus = true);
    try {
      final details = await widget.auth.fetchProjectById(widget.projectId);
      final updatedStages = [...details.stages];
      if (updatedStages.length > widget.stageIndex) {
        updatedStages[widget.stageIndex] =
            updatedStages[widget.stageIndex].copyWith(status: _status);
      }
      await widget.auth.updateProject(
        details.id,
        details.toPatchJson(stagesOverride: updatedStages),
      );
      await widget.onUpdated();
      await _refreshStage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус обновлён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _savingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.role == 'client';
    final statusLabel = kStageStatusLabels[_status] ?? _status;
    final progress = _progressByStatus(_status);
    final tone = _toneByStatus(_status);
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(
        title: Text(_stage.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tone.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tone,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: UiTokens.foreground(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: UiTokens.surface(context),
                    valueColor: AlwaysStoppedAnimation<Color>(tone),
                  ),
                ),
                const SizedBox(height: 14),
                _MetaTile(
                  icon: Icons.event_outlined,
                  title: 'План',
                  value:
                      '${formatDateRu(_stage.plannedStart)} — ${formatDateRu(_stage.plannedEnd)}',
                ),
                const SizedBox(height: 10),
                _MetaTile(
                  icon: Icons.info_outline,
                  title: 'Ответственный',
                  value: _stage.stageComment.trim().isEmpty
                      ? '—'
                      : _stage.stageComment.trim(),
                ),
              ],
            ),
          ),
          if (!isClient) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: UiTokens.cardShadow(context),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: kStageStatusLabels.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Статус этапа'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _savingStatus ? null : _saveStageStatus,
                    child: _savingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Фото этапа',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_stage.photoUrls.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Фото пока не добавлены',
                style: TextStyle(color: UiTokens.muted(context)),
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _stage.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final url = _resolveUrl(_stage.photoUrls[idx]);
                  return InkWell(
                    onTap: () => _openPhotoGallery(idx),
                    borderRadius: BorderRadius.circular(14),
                    child: Hero(
                      tag: 'stage-photo-$idx-$url',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          url,
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) => Container(
                            width: 160,
                            height: 120,
                            color: UiTokens.surface(context),
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          if (!isClient)
            OutlinedButton.icon(
              onPressed: _uploadingPhoto ? null : _addStagePhotos,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_uploadingPhoto ? 'Загрузка...' : 'Добавить фото'),
            ),
          const SizedBox(height: 16),
          Text(
            'Комментарий',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 8),
          if (isClient)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _stage.comments.isEmpty ? '—' : _stage.comments,
                style: TextStyle(color: UiTokens.muted(context), height: 1.35),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: UiTokens.cardShadow(context),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Оставьте комментарий',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _savingComment ? null : _saveStageComment,
                      child: _savingComment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить комментарий'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _progressByStatus(String status) {
    switch (status) {
      case 'completed':
        return 1;
      case 'in_progress':
        return 0.55;
      default:
        return 0.1;
    }
  }

  Color _toneByStatus(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return UiTokens.accent;
      default:
        return UiTokens.muted(context);
    }
  }

  void _openPhotoGallery(int initialIndex) {
    final photos = _stage.photoUrls.map(_resolveUrl).toList(growable: false);
    final controller = PageController(initialPage: initialIndex);
    int currentIndex = initialIndex;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                onPageChanged: (value) {
                  setDialogState(() => currentIndex = value);
                },
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index];
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Hero(
                        tag: 'stage-photo-$index-$url',
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, _, __) => Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${currentIndex + 1} / ${photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.isEmpty) return raw;
    if (raw.startsWith('/')) return '${ApiConfig.baseUrl}$raw';
    return '${ApiConfig.baseUrl}/$raw';
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UiTokens.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: UiTokens.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: UiTokens.muted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: UiTokens.foreground(context),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
