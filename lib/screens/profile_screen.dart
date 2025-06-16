import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // Untuk Uint8List
import 'package:universal_html/html.dart' as html; // Impor universal_html untuk web
import 'dart:io' as io; // Impor dart:io dengan alias untuk menghindari konflik
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  final PocketBase pb;

  const ProfileScreen({super.key, required this.pb});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3;
  String _userName = 'Felicia Paramdayani A.P';
  String _userEmail = 'feliciaa2811@gmail.com';
  dynamic _selectedImage; // Mendukung io.File (mobile) atau Uint8List (web)
  Uint8List? _imageBytes; // Untuk menampilkan gambar di web
  bool _isLoading = false;
  String? _profilePictureUrl;
  bool _isWeb = false; // Flag untuk mendeteksi platform

  @override
  void initState() {
    super.initState();
    // Deteksi platform saat inisialisasi
    _isWeb = html.window != null;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = widget.pb.authStore.model?.id;
      if (userId == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final record = await widget.pb.collection('users').getOne(userId);
      setState(() {
        _userName = record.data['name'] ?? 'Felicia Paramdayani A.P';
        _userEmail = record.data['email'] ?? 'feliciaa2811@gmail.com';
        if (record.data['profilePicture'] != null) {
          _profilePictureUrl = widget.pb.files.getUrl(record, record.data['profilePicture']).toString();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch user data: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (_isWeb) {
        // Web
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
          _imageBytes = bytes; // Untuk pratinjau gambar di web
        });
      } else {
        // Mobile (Android/iOS)
        setState(() {
          _selectedImage = io.File(pickedFile.path);
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/add_task');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/projects'); // Updated from '/kanban' to '/projects'
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.pb.authStore.clear();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    TextEditingController nameController = TextEditingController(text: _userName);
    TextEditingController emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _pickImage();
                        setDialogState(() {});
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: _selectedImage != null
                            ? (_isWeb
                                ? MemoryImage(_imageBytes!)
                                : FileImage(_selectedImage as io.File))
                            : (_profilePictureUrl != null
                                ? NetworkImage(_profilePictureUrl!)
                                : const NetworkImage('https://via.placeholder.com/150')),
                        child: const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_isLoading) return;
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final userId = widget.pb.authStore.model?.id;
                      if (userId == null) {
                        Navigator.pushReplacementNamed(context, '/login');
                        return;
                      }

                      final body = {
                        'name': nameController.text,
                        'email': emailController.text,
                      };

                      if (_selectedImage != null) {
                        http.MultipartFile file; // Eksplisit deklarasi sebagai MultipartFile
                        if (_isWeb) {
                          file = http.MultipartFile.fromBytes(
                            'profilePicture',
                            _imageBytes!,
                            filename: 'profilePicture.jpg',
                          );
                        } else {
                          file = await http.MultipartFile.fromPath(
                            'profilePicture',
                            (_selectedImage as io.File).path,
                            filename: 'profilePicture.${(_selectedImage as io.File).path.split('.').last}',
                          );
                        }
                        final updatedRecord = await widget.pb.collection('users').update(
                          userId,
                          body: body,
                          files: [file], // Sekarang file dijamin bertipe MultipartFile
                        );
                        if (updatedRecord.data['profilePicture'] != null) {
                          setState(() {
                            _userName = updatedRecord.data['name'];
                            _userEmail = updatedRecord.data['email'];
                            _profilePictureUrl = widget.pb.files
                                .getUrl(updatedRecord, updatedRecord.data['profilePicture'])
                                .toString();
                            _selectedImage = null; // Reset setelah unggah
                            _imageBytes = null;
                          });
                        }
                      } else {
                        final updatedRecord = await widget.pb.collection('users').update(userId, body: body);
                        setState(() {
                          _userName = updatedRecord.data['name'];
                          _userEmail = updatedRecord.data['email'];
                        });
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _editProfile,
                ),
              ],
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: _selectedImage != null
                  ? (_isWeb
                      ? MemoryImage(_imageBytes!)
                      : FileImage(_selectedImage as io.File))
                  : (_profilePictureUrl != null
                      ? NetworkImage(_profilePictureUrl!)
                      : const NetworkImage('https://via.placeholder.com/150')),
            ),
            const SizedBox(height: 16),
            Text(
              _userName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 24,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _userEmail,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _editProfile,
              ),
            ),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: Text(
                  'Dark Mode',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                value: Theme.of(context).brightness == Brightness.dark,
                activeColor: const Color(0xFFF8E1E1),
                onChanged: (value) {
                  TaskFlowApp.themeModeNotifier.value =
                      value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text(
                  'Logout',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add Task'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Projects'), // Updated icon and label
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
