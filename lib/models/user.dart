class User {
  User({
    required this.id,
    required this.fullName,
    required this.address,
    required this.age,
    required this.email,
    required this.password,
    required this.idFrontPath,
    required this.idBackPath,
    this.profilePicture,
    this.bio,
    this.phoneNumber,
    this.gcashName,
    this.gcashNumber,
    this.urcodePath,
    this.createdAt,
  });

  final int id;
  final String fullName;
  final String address;
  final int age;
  final String email;
  final String password;
  final String idFrontPath;
  final String idBackPath;
  String? profilePicture;
  String? bio;
  String? phoneNumber;
  String? gcashName;
  String? gcashNumber;
  String? urcodePath;
  DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'address': address,
      'age': age,
      'email': email,
      'password': password,
      'id_front_path': idFrontPath,
      'id_back_path': idBackPath,
      'profile_picture': profilePicture,
      'bio': bio,
      'phone_number': phoneNumber,
      'gcash_name': gcashName,
      'gcash_number': gcashNumber,
      'urcode_path': urcodePath,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      fullName: map['full_name'] as String,
      address: map['address'] as String,
      age: map['age'] as int,
      email: map['email'] as String,
      password: map['password'] as String,
      idFrontPath: map['id_front_path'] as String,
      idBackPath: map['id_back_path'] as String,
      profilePicture: map['profile_picture'] as String?,
      bio: map['bio'] as String?,
      phoneNumber: map['phone_number'] as String?,
      gcashName: map['gcash_name'] as String?,
      gcashNumber: map['gcash_number'] as String?,
      urcodePath: map['urcode_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}