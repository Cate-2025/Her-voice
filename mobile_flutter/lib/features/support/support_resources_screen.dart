import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/hervoice_repository.dart';
import '../../models/support_resource.dart';
import '../../widgets/empty_state.dart';
import 'emergency_screen.dart';

/// Support-resource directory (section 3.9, secondary feature).
class SupportResourcesScreen extends StatefulWidget {
  const SupportResourcesScreen({super.key});

  @override
  State<SupportResourcesScreen> createState() => _SupportResourcesScreenState();
}

class _SupportResourcesScreenState extends State<SupportResourcesScreen> {
  SupportDirectory? _directory;
  String? _error;
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SupportDirectory directory =
          await context.read<HerVoiceRepository>().supportDirectory();
      if (!mounted) return;
      setState(() => _directory = directory);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupportDirectory? directory = _directory;

    return Scaffold(
      appBar: AppBar(title: const Text('Support & resources')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: directory == null
                  ? ListView(
                      children: <Widget>[
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.support_agent_outlined,
                          title: 'Directory unavailable',
                          message: _error ??
                              'The support directory needs a connection to the HERVOICE server.',
                        ),
                      ],
                    )
                  : _buildList(context, directory),
            ),
    );
  }

  Widget _buildList(BuildContext context, SupportDirectory directory) {
    final List<SupportResource> visible =
        _filter == 'All' ? directory.resources : directory.byCategory(_filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
        Card(
          color: const Color(0xFFFFEBEE),
          child: ListTile(
            leading:
                const Icon(Icons.emergency_outlined, color: HerVoiceColors.danger),
            title: const Text(
              'Need help right now?',
              style: TextStyle(fontWeight: FontWeight.w700, color: HerVoiceColors.danger),
            ),
            subtitle: const Text('Open quick support and emergency contacts.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <String>['All', ...directory.categories]
                .map((String category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _filter == category,
                        onSelected: (_) => setState(() => _filter = category),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        ...visible.map((SupportResource resource) => _ResourceCard(resource: resource)),
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final SupportResource resource;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resource.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: HerVoiceColors.pinkLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    resource.category,
                    style: const TextStyle(
                      fontSize: 10,
                      color: HerVoiceColors.pinkPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(resource.description, style: const TextStyle(fontSize: 12, height: 1.4)),
            if (resource.availability != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  resource.availability!,
                  style: const TextStyle(fontSize: 11, color: HerVoiceColors.textMuted),
                ),
              ),
            if (resource.contact != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        resource.contact!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HerVoiceColors.pinkPrimaryDark,
                        ),
                      ),
                    ),
                    if (resource.walkIn)
                      const Chip(
                        label: Text('Walk-in welcome', style: TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            if (resource.contact != null && resource.contact!.contains('@'))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: resource.contact!)),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('Copy contact', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
