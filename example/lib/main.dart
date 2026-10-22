import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:xue_hua_navite_share/xue_hua_navite_share.dart';
import 'package:xue_hua_navite_share_example/app_theme.dart';

void main() {
  runApp(const XueHuaShareExampleApp());
}

/// Comprehensive example application demonstrating all 6-platform features
/// of the `xue_hua_navite_share` plugin.
class XueHuaShareExampleApp extends StatelessWidget {
  const XueHuaShareExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Native Share Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const ShareWorkbenchPage(),
    );
  }
}

/// Interactive workbench page for testing all capabilities of [XueHuaNaviteShare].
class ShareWorkbenchPage extends StatefulWidget {
  const ShareWorkbenchPage({super.key});

  @override
  State<ShareWorkbenchPage> createState() => _ShareWorkbenchPageState();
}

class _ShareWorkbenchPageState extends State<ShareWorkbenchPage> {
  final XueHuaNaviteShare _sharePlugin = XueHuaNaviteShare.instance;

  final TextEditingController _textController = TextEditingController(
    text:
        'Check out xue_hua_navite_share — a full-featured 6-platform native share plugin for Flutter!',
  );
  final TextEditingController _subjectController = TextEditingController(
    text: 'XueHua Native Share Plugin',
  );
  final TextEditingController _titleController = TextEditingController(
    text: 'Share via XueHua Native Share',
  );
  final TextEditingController _urlController = TextEditingController(
    text: 'https://github.com/Matkurban/xue_hua_navite_share',
  );
  final TextEditingController _filePathController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController(
    text: '3496354336@qq.com',
  );

  SharePreferredEdge _preferredEdge = SharePreferredEdge.maxY;
  ShareTargetService _targetService = ShareTargetService.systemSheet;
  bool _excludePrint = false;
  bool _excludeAirDrop = false;
  bool _fallbackToClipboard = true;

  SharePlatformCapabilities? _capabilities;
  ShareResult? _lastResult;
  bool? _lastCanShare;
  int? _lastCleanedCount;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  @override
  void dispose() {
    _textController.dispose();
    _subjectController.dispose();
    _titleController.dispose();
    _urlController.dispose();
    _filePathController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    try {
      final caps = await _sharePlugin.getCapabilities();
      if (!mounted) return;
      setState(() {
        _capabilities = caps;
      });
    } catch (_) {
      // Ignore capability lookup errors in headless test environments.
    }
  }

  /// Resolves the global window coordinates of the tapped button's [BuildContext]
  /// so iPadOS (`UIPopoverPresentationController`) and macOS (`NSSharingServicePicker`)
  /// anchor the popover directly to the triggering button.
  ShareAnchorRect? _resolveAnchorRect(BuildContext buttonContext) {
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final offset = renderObject.localToGlobal(Offset.zero);
      return ShareAnchorRect.fromRect(offset & renderObject.size);
    }
    return null;
  }

  List<ShareActivityType> get _selectedExclusions => <ShareActivityType>[
    if (_excludePrint) ShareActivityType.print,
    if (_excludeAirDrop) ShareActivityType.airDrop,
  ];

  Future<void> _handleShareText(BuildContext buttonContext) async {
    final result = await _sharePlugin.shareText(
      _textController.text,
      subject: _subjectController.text,
      title: _titleController.text,
      anchorRect: _resolveAnchorRect(buttonContext),
      preferredEdge: _preferredEdge,
      excludedActivityTypes: _selectedExclusions,
      fallbackToClipboard: _fallbackToClipboard,
    );
    _updateResult(result);
  }

  Future<void> _handleShareUri(BuildContext buttonContext) async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null) return;

    Uint8List previewUint8List = await _buildSamplePngBytes();

    final result = await _sharePlugin.shareUri(
      uri,
      title: _titleController.text,
      subject: _subjectController.text,
      message: _textController.text,
      previewThumbnail: previewUint8List,
      anchorRect: _resolveAnchorRect(buttonContext),
      preferredEdge: _preferredEdge,
      excludedActivityTypes: _selectedExclusions,
      fallbackToClipboard: _fallbackToClipboard,
    );
    _updateResult(result);
  }

  Future<void> _handleShareMemoryItems(BuildContext buttonContext) async {
    final jsonContent = const JsonEncoder.withIndent('  ')
        .convert(<String, Object?>{
          'plugin': 'xue_hua_navite_share',
          'author': 'Matkurban',
          'email': '3496354336@qq.com',
          'repository': 'https://github.com/Matkurban/xue_hua_navite_share',
          'timestamp': DateTime.now().toIso8601String(),
        });

    Uint8List previewUint8List = await _buildSamplePngBytes();

    final memoryItems = <ShareItem>[
      ShareItem.memory(
        bytes: Uint8List.fromList(utf8.encode(jsonContent)),
        fileName: 'xue_hua_share_metadata.json',
        mimeType: 'application/json',
        subject: _subjectController.text,
      ),
      ShareItem.memory(
        bytes: previewUint8List,
        fileName: 'sample_badge.png',
        mimeType: 'image/png',
        subject: 'Sample PNG Image',
      ),
    ];

    final result = await _sharePlugin.shareMemoryFiles(
      memoryItems,
      text: _textController.text,
      subject: _subjectController.text,
      title: _titleController.text,
      anchorRect: _resolveAnchorRect(buttonContext),
      preferredEdge: _preferredEdge,
      excludedActivityTypes: _selectedExclusions,
    );
    _updateResult(result);
  }

  Future<void> _handleShareLocalFiles(BuildContext buttonContext) async {
    final rawPaths = _filePathController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (rawPaths.isEmpty) {
      setState(() {
        _lastResult = const ShareResult(
          status: ShareResultStatus.error,
          message:
              'Please enter at least one local file path separated by commas.',
        );
      });
      return;
    }

    final result = await _sharePlugin.shareFiles(
      rawPaths,
      text: _textController.text,
      subject: _subjectController.text,
      title: _titleController.text,
      anchorRect: _resolveAnchorRect(buttonContext),
      preferredEdge: _preferredEdge,
      excludedActivityTypes: _selectedExclusions,
    );
    _updateResult(result);
  }

  Future<void> _handleShareCustomPayload(BuildContext buttonContext) async {
    final uri = Uri.tryParse(_urlController.text.trim());
    final recipients = _recipientController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Uint8List previewUint8List = await _buildSamplePngBytes();

    final params = ShareParams(
      items: <ShareItem>[
        ShareItem.memory(
          bytes: Uint8List.fromList(utf8.encode(_textController.text)),
          fileName: 'shared_note.txt',
          mimeType: 'text/plain',
        ),
      ],
      text: _textController.text,
      uri: uri,
      subject: _subjectController.text,
      title: _titleController.text,
      previewThumbnail: previewUint8List,
      anchorRect: _resolveAnchorRect(buttonContext),
      preferredEdge: _preferredEdge,
      excludedActivityTypes: _selectedExclusions,
      targetService: _targetService,
      emailRecipients: recipients,
      fallbackToClipboard: _fallbackToClipboard,
    );

    final canShare = await _sharePlugin.canShare(params);
    final result = await _sharePlugin.share(params);
    if (!mounted) return;
    setState(() {
      _lastCanShare = canShare;
      _lastResult = result;
    });
  }

  Future<void> _handleCleanupTempFiles() async {
    final count = await _sharePlugin.cleanupTempFiles();
    if (!mounted) return;
    setState(() {
      _lastCleanedCount = count;
    });
  }

  void _updateResult(ShareResult result) {
    if (!mounted) return;
    setState(() {
      _lastResult = result;
    });
  }

  /// Generates a valid 1x1 blue PNG image in memory for rich preview & file tests.
  Future<Uint8List> _buildSamplePngBytes() async {
    ByteData byteData = await rootBundle.load('assets/images/img1.jpg');
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XueHua Native Share Workbench'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh Platform Capabilities',
            onPressed: _loadCapabilities,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cleanup Temporary Share Files',
            onPressed: _handleCleanupTempFiles,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildCapabilitiesCard(),
          const SizedBox(height: 16),
          _buildPayloadConfigCard(),
          const SizedBox(height: 16),
          _buildOptionsCard(),
          const SizedBox(height: 16),
          _buildActionsCard(),
          const SizedBox(height: 16),
          _buildResultCard(),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    final caps = _capabilities;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Host Platform Capabilities',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (caps == null)
              const Text('Loading platform capabilities...')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text('Platform: ${caps.platform}')),
                  Chip(
                    label: Text(
                      'System Sheet: ${caps.supportsSystemShareSheet}',
                    ),
                  ),
                  Chip(
                    label: Text('Multi-File: ${caps.supportsMultipleFiles}'),
                  ),
                  Chip(
                    label: Text(
                      'Memory Bytes: ${caps.supportsMemoryBytesSharing}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Popover Anchor: ${caps.supportsAnchorPopover}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Target Callback: ${caps.supportsChosenTargetCallback}',
                    ),
                  ),
                ],
              ),
            if (caps != null && caps.availableServices.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Available Services: ${caps.availableServices.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Share Payload Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Chooser / Preview Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Line (Email / Rich Metadata)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Share Text / Message Caption',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Share URI / URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filePathController,
              decoration: const InputDecoration(
                labelText: 'Local File Paths (comma-separated)',
                hintText: '/path/to/image.png, /path/to/document.pdf',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Email Recipients (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Platform & Service Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 12,
                  child: DropdownButtonFormField<ShareTargetService>(
                    initialValue: _targetService,
                    decoration: const InputDecoration(
                      labelText: 'Target Service',
                      visualDensity: VisualDensity.compact,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: ShareTargetService.values.map((service) {
                      return DropdownMenuItem<ShareTargetService>(
                        value: service,
                        child: Text(service.wireName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _targetService = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 8,
                  child: DropdownButtonFormField<SharePreferredEdge>(
                    initialValue: _preferredEdge,
                    decoration: const InputDecoration(
                      labelText: 'Popover Edge (macOS / iPadOS)',
                      visualDensity: VisualDensity.compact,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: SharePreferredEdge.values.map((edge) {
                      return DropdownMenuItem<SharePreferredEdge>(
                        value: edge,
                        child: Text(edge.wireName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _preferredEdge = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: <Widget>[
                FilterChip(
                  label: const Text('Exclude Print'),
                  selected: _excludePrint,
                  onSelected: (v) => setState(() => _excludePrint = v),
                ),
                FilterChip(
                  label: const Text('Exclude AirDrop'),
                  selected: _excludeAirDrop,
                  onSelected: (v) => setState(() => _excludeAirDrop = v),
                ),
                FilterChip(
                  label: const Text('Fallback to Clipboard'),
                  selected: _fallbackToClipboard,
                  onSelected: (v) => setState(() => _fallbackToClipboard = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Share Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                Builder(
                  builder: (btnCtx) => FilledButton.icon(
                    onPressed: () => _handleShareText(btnCtx),
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Share Text'),
                  ),
                ),
                Builder(
                  builder: (btnCtx) => FilledButton.icon(
                    onPressed: () => _handleShareUri(btnCtx),
                    icon: const Icon(Icons.link),
                    label: const Text('Share URI + Preview'),
                  ),
                ),
                Builder(
                  builder: (btnCtx) => FilledButton.icon(
                    onPressed: () => _handleShareMemoryItems(btnCtx),
                    icon: const Icon(Icons.memory),
                    label: const Text('Share In-Memory Files (JSON + PNG)'),
                  ),
                ),
                Builder(
                  builder: (btnCtx) => OutlinedButton.icon(
                    onPressed: () => _handleShareLocalFiles(btnCtx),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Share Local File Paths'),
                  ),
                ),
                Builder(
                  builder: (btnCtx) => FilledButton.tonalIcon(
                    onPressed: () => _handleShareCustomPayload(btnCtx),
                    icon: const Icon(Icons.send),
                    label: Text('Share via ${_targetService.wireName}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final res = _lastResult;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Latest Share Result & Diagnostics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (res == null)
              const Text(
                'Trigger any share action above to inspect the result.',
              )
            else ...<Widget>[
              Text(
                'Status: ${res.status.wireName} (isSuccess: ${res.isSuccess})',
              ),
              Text('Selected Activity: ${res.selectedActivityType ?? "N/A"}'),
              Text('Message: ${res.message ?? "N/A"}'),
            ],
            if (_lastCanShare != null)
              Text('Last canShare() check: $_lastCanShare'),
            if (_lastCleanedCount != null)
              Text(
                'Last cleanupTempFiles() removed: $_lastCleanedCount file(s)',
              ),
          ],
        ),
      ),
    );
  }
}
