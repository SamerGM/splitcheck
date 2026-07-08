// lib/core/services/edit_parser.dart

enum EditAction { editPrice, editPersons, editBoth, remove }

class EditCommand {
  final EditAction action;
  final String itemKeyword;
  final double? newPrice;
  final List<String> newPersons;

  const EditCommand({
    required this.action,
    required this.itemKeyword,
    this.newPrice,
    this.newPersons = const [],
  });
}

EditCommand? parseEditCommand(String input) {
  final text = input.trim().toLowerCase();

  if (text.startsWith('remove ') || text.startsWith('delete ')) {
    final keyword = input.trim().split(' ').skip(1).join(' ').trim();
    if (keyword.isEmpty) return null;
    return EditCommand(action: EditAction.remove, itemKeyword: keyword);
  }

  if (text.startsWith('edit ')) {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    final keyword = parts[1];
    final rest = parts.skip(2).toList();
    final price = double.tryParse(rest.first);
    if (price != null && price > 0) {
      final persons = rest.skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return EditCommand(
        action: persons.isEmpty ? EditAction.editPrice : EditAction.editBoth,
        itemKeyword: keyword,
        newPrice: price,
        newPersons: persons,
      );
    } else {
      return EditCommand(
        action: EditAction.editPersons,
        itemKeyword: keyword,
        newPersons: rest.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
    }
  }
  return null;
}
