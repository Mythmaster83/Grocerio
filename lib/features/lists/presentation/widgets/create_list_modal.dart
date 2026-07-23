import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../providers/list_actions_controller.dart';

Future<void> showCreateListModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const _CreateListForm(),
    ),
  );
}

class _CreateListForm extends ConsumerStatefulWidget {
  const _CreateListForm();
  @override
  ConsumerState<_CreateListForm> createState() => _CreateListFormState();
}

class _CreateListFormState extends ConsumerState<_CreateListForm> {
  final _nameController = TextEditingController();
  ScheduleFrequency _frequency = ScheduleFrequency.weekly;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'List name is required.');
      return;
    }
    final ok = await ref.read(listActionsControllerProvider.notifier).createList(
          name: _nameController.text,
          frequency: _frequency,
          explicitDate: _date,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Could not create the list. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(listActionsControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New list', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'e.g. Weekly groceries'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ScheduleFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Repeats'),
            items: ScheduleFrequency.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                .toList(),
            onChanged: (f) => setState(() => _frequency = f ?? _frequency),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scheduled for'),
            subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: actionState.isLoading ? null : _submit,
            child: actionState.isLoading
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create List'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
