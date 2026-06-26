class UserModel {
  final String uid;
  final String email;
  final String name;
  final String emergencyContact;
  final String inviteCode;
  final String? profilePhoto;
  final String? fcmToken; // NUEVO: Para notificaciones push

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.emergencyContact,
    required this.inviteCode,
    this.profilePhoto,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'emergencyContact': emergencyContact,
      'inviteCode': inviteCode,
      'profilePhoto': profilePhoto,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      emergencyContact: map['emergencyContact'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      profilePhoto: map['profilePhoto'],
      fcmToken: map['fcmToken'],
    );
  }
}
