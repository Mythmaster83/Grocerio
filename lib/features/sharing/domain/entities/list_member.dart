import 'package:equatable/equatable.dart';

class ListMember extends Equatable {
  final String userId;

  /// Null when the invited account has no email on file, which shouldn't
  /// normally happen but is not worth failing a member list over.
  final String? email;
  final String role;
  final bool isOwner;

  const ListMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.isOwner,
  });

  String get label => email ?? 'Unknown account';

  @override
  List<Object?> get props => [userId, email, role, isOwner];
}
