class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;
  final String password; // Add password field for authentication

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'password': password,
      };

  static UserModel fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'],
        firstName: json['firstName'],
        lastName: json['lastName'],
        username: json['username'],
        password: json['password'],
      );
}
