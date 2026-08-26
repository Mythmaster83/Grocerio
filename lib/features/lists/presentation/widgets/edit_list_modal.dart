import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../../domain/entities/grocery_list.dart';
import '../providers/list_actions_controller.dart';

/// Rename / reschedule / change how often a list repeats, without opening it —
/// reached from the 3-dot menu on each card on the home screen.
Future<void> showEditListModal(BuildContext context, {required GroceryList list}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditListForm(list: list),
  );
}

class _EditListForm extends ConsumerStatefulWidget {
  final GroceryList list;
  const _EditListForm({required this.list});

  @override
  ConsumerState<_EditListForm> createState() => _EditListFormState();
}

class _EditListFormState extends ConsumerState<_EditListForm> {
  late final TextEditingController _nameController;
  late DateTime _date;
  late ScheduleFrequency _frequency;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
    _date = widget.list.scheduledFor;
    _frequency = widget.list.frequency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Allow past dates: a list can legitimately be rescheduled to a date
      // that has already passed (e.g. "I meant last Friday").
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'List name is required.');
      return;
    }

    final ok = await ref.read(listActionsControllerProvider.notifier).updateList(
          listId: widget.list.id,
          name: name,
          scheduledFor: _date,
          frequency: _frequency,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Could not save the changes. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(listActionsControllerProvider);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit list', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'List name'),
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
              subtitle: Text(DateFormat.yMMMEd().format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: actionState.isLoading ? null : _submit,
              child: actionState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
