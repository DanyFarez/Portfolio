import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PortfolioApp());
}

class PortfolioApp extends StatefulWidget {
  const PortfolioApp({super.key});

  @override
  State<PortfolioApp> createState() => _PortfolioAppState();
}

class _PortfolioAppState extends State<PortfolioApp> {
  bool isDarkMode = true;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Danny | Portfolio',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardColor: Colors.white,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        cardColor: const Color(0xFF121620),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: PortfolioHomeScreen(onThemeToggle: toggleTheme, isDarkMode: isDarkMode),
    );
  }
}

class PortfolioHomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const PortfolioHomeScreen({super.key, required this.onThemeToggle, required this.isDarkMode});

  @override
  State<PortfolioHomeScreen> createState() => _PortfolioHomeScreenState();
}

class _PortfolioHomeScreenState extends State<PortfolioHomeScreen> {
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        isOwner = user != null;
      });
    });
    _initializeDefaultSectionIfNeeded();
  }

  Future<void> _initializeDefaultSectionIfNeeded() async {
    try {
      final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
      final sectionsSnapshot = await db.collection('sections').get();
      
      // If no sections exist, create a default "Featured Projects" section
      if (sectionsSnapshot.docs.isEmpty) {
        final newSectionRef = await db.collection('sections').add({
          'title': 'Featured Projects',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Migrate old 'projects' collection if any exist
        final oldProjects = await db.collection('projects').get();
        for (var doc in oldProjects.docs) {
          final data = doc.data();
          await db.collection('section_items').add({
            'sectionId': newSectionRef.id,
            'title': data['title'] ?? '',
            'description': data['description'] ?? '',
            'link': data['link'] ?? '',
            'iconBase64': data['iconBase64'],
            'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  void _showLoginDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text("Owner Login", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.grey))),
            const SizedBox(height: 12),
            TextField(controller: passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.grey))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Login failed: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, Map<String, dynamic> currentData) {
    final logoController = TextEditingController(text: currentData['logoText'] ?? "DANNY.DEV");
    final nameController = TextEditingController(text: currentData['name'] ?? "Danny 👋");
    final titleController = TextEditingController(text: currentData['title'] ?? "Flutter Developer & UI/UX Creator");
    
    final githubController = TextEditingController(text: currentData['githubUrl'] ?? "");
    final linkedinController = TextEditingController(text: currentData['linkedinUrl'] ?? "");
    final twitterController = TextEditingController(text: currentData['twitterUrl'] ?? "");
    final instagramController = TextEditingController(text: currentData['instagramUrl'] ?? "");
    final emailController = TextEditingController(text: currentData['emailUrl'] ?? "");

    String? avatarBase64 = currentData['avatarBase64'];
    String? bannerBase64 = currentData['bannerBase64'];
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text("Edit Portfolio Branding & Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Branding & Profile", style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: logoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Navbar Logo / Text", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 12),
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Your Nickname / Name", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 12),
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Sub-headline / Bio", labelStyle: TextStyle(color: Colors.grey))),
                
                const SizedBox(height: 20),
                const Text("Social Media Accounts", style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: githubController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "GitHub URL", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                TextField(controller: linkedinController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "LinkedIn URL", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                TextField(controller: twitterController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Twitter / X URL", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                TextField(controller: instagramController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Instagram URL", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Email Address", labelStyle: TextStyle(color: Colors.grey))),
                
                const SizedBox(height: 20),
                if (isProcessing)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
                    icon: const Icon(Icons.person, color: Color(0xFF818CF8)),
                    label: const Text("Change Profile Picture"),
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 80);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setDialogState(() => avatarBase64 = base64Encode(bytes));
                        }
                      } catch (e) {
                        debugPrint('$e');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
                    icon: const Icon(Icons.wallpaper, color: Color(0xFF818CF8)),
                    label: const Text("Change Wallpaper Banner"),
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 600, imageQuality: 80);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setDialogState(() => bannerBase64 = base64Encode(bytes));
                        }
                      } catch (e) {
                        debugPrint('$e');
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              onPressed: isProcessing ? null : () async {
                try {
                  final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
                  await db.collection('settings').doc('profile').set({
                    'logoText': logoController.text.trim(),
                    'name': nameController.text.trim(),
                    'title': titleController.text.trim(),
                    'githubUrl': githubController.text.trim(),
                    'linkedinUrl': linkedinController.text.trim(),
                    'twitterUrl': twitterController.text.trim(),
                    'instagramUrl': instagramController.text.trim(),
                    'emailUrl': emailController.text.trim(),
                    'avatarBase64': avatarBase64,
                    'bannerBase64': bannerBase64,
                  }, SetOptions(merge: true));
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionDialog(BuildContext context, {DocumentSnapshot? doc}) {
    final titleController = TextEditingController(text: doc != null ? doc['title'] : '');
    String? headerIconBase64 = doc != null && doc.data().toString().contains('headerIconBase64') ? doc['headerIconBase64'] : null;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(doc == null ? "Add New Portfolio Section" : "Edit Section", style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Section Title", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 16),
                if (isProcessing)
                  const CircularProgressIndicator(color: Color(0xFF6366F1))
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
                    icon: const Icon(Icons.image, color: Color(0xFF818CF8)),
                    label: const Text("Upload Custom Section Icon"),
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 150, maxHeight: 150, imageQuality: 80);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setDialogState(() => headerIconBase64 = base64Encode(bytes));
                        }
                      } catch (e) {
                        debugPrint('$e');
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              onPressed: isProcessing ? null : () async {
                if (titleController.text.isNotEmpty) {
                  try {
                    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
                    if (doc == null) {
                      await db.collection('sections').add({
                        'title': titleController.text.trim(),
                        'headerIconBase64': headerIconBase64,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await db.collection('sections').doc(doc.id).update({
                        'title': titleController.text.trim(),
                        'headerIconBase64': headerIconBase64,
                      });
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text("Save Section"),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDialog(BuildContext context, String sectionId, {DocumentSnapshot? doc}) {
    final titleController = TextEditingController(text: doc != null ? doc['title'] : '');
    final descController = TextEditingController(text: doc != null ? doc['description'] : '');
    final linkController = TextEditingController(text: doc != null && doc.data().toString().contains('link') ? doc['link'] : '');
    String? iconBase64 = doc != null && doc.data().toString().contains('iconBase64') ? doc['iconBase64'] : null;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(doc == null ? "Add Item to Section" : "Edit Item", style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Item Title", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 12),
                TextField(controller: linkController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Live Link / URL (Optional)", labelStyle: TextStyle(color: Colors.grey))),
                const SizedBox(height: 16),
                if (isProcessing)
                  const CircularProgressIndicator(color: Color(0xFF6366F1))
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
                    icon: const Icon(Icons.image, color: Color(0xFF818CF8)),
                    label: const Text("Upload Item Thumbnail/Icon"),
                    onPressed: () async {
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 200, maxHeight: 200, imageQuality: 80);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setDialogState(() => iconBase64 = base64Encode(bytes));
                        }
                      } catch (e) {
                        debugPrint('$e');
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              onPressed: isProcessing ? null : () async {
                if (titleController.text.isNotEmpty) {
                  try {
                    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
                    if (doc == null) {
                      await db.collection('section_items').add({
                        'sectionId': sectionId,
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'link': linkController.text.trim(),
                        'iconBase64': iconBase64,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await db.collection('section_items').doc(doc.id).update({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'link': linkController.text.trim(),
                        'iconBase64': iconBase64,
                      });
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text("Save Item"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString.startsWith('mailto:') || urlString.startsWith('http') ? urlString : 'https://$urlString');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildSocialBadge(IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    final isDark = widget.isDarkMode;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('settings').doc('profile').snapshots(),
        builder: (context, profileSnapshot) {
          final profileData = profileSnapshot.hasData && profileSnapshot.data!.exists
              ? profileSnapshot.data!.data() as Map<String, dynamic>
              : {
                  'logoText': 'DANNY.DEV',
                  'name': 'Danny 👋',
                  'title': 'Flutter Developer & UI/UX Creator',
                };

          Uint8List? avatarBytes;
          if (profileData['avatarBase64'] != null) {
            try {
              avatarBytes = base64Decode(profileData['avatarBase64']);
            } catch (_) {}
          }

          Uint8List? bannerBytes;
          if (profileData['bannerBase64'] != null) {
            try {
              bannerBytes = base64Decode(profileData['bannerBase64']);
            } catch (_) {}
          }

          final String githubUrl = profileData['githubUrl'] ?? '';
          final String linkedinUrl = profileData['linkedinUrl'] ?? '';
          final String twitterUrl = profileData['twitterUrl'] ?? '';
          final String instagramUrl = profileData['instagramUrl'] ?? '';
          final String emailUrl = profileData['emailUrl'] ?? '';

          return SingleChildScrollView(
            child: SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- NAVBAR ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    profileData['logoText'] ?? 'DANNY.DEV',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
                                tooltip: "Toggle Theme",
                                onPressed: widget.onThemeToggle,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              if (isOwner) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                                  ),
                                  child: const Text("Edit ON", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings_rounded, size: 18, color: Color(0xFF818CF8)),
                                  tooltip: "Customize Branding",
                                  onPressed: () => _showEditProfileDialog(context, profileData),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                  tooltip: "Logout",
                                  onPressed: () => FirebaseAuth.instance.signOut(),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ] else ...[
                                IconButton(
                                  icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                                  tooltip: "Owner Login",
                                  onPressed: () => _showLoginDialog(context),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // --- HERO BANNER ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
                        decoration: BoxDecoration(
                          image: bannerBytes != null
                              ? DecorationImage(image: MemoryImage(bannerBytes), fit: BoxFit.cover)
                              : null,
                          gradient: bannerBytes == null
                              ? const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFDB2777)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withOpacity(0.6) : const Color(0xFF4F46E5).withOpacity(0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF818CF8), width: 3),
                                ),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                                  child: avatarBytes == null ? const Icon(Icons.person, size: 45, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                profileData['name'] ?? 'Danny 👋',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  profileData['title'] ?? '',
                                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              // --- SOCIAL ACCOUNTS ROW ---
                              if (githubUrl.isNotEmpty || linkedinUrl.isNotEmpty || twitterUrl.isNotEmpty || instagramUrl.isNotEmpty || emailUrl.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (githubUrl.isNotEmpty) _buildSocialBadge(Icons.code, "GitHub", githubUrl),
                                    if (linkedinUrl.isNotEmpty) _buildSocialBadge(Icons.business_center, "LinkedIn", linkedinUrl),
                                    if (twitterUrl.isNotEmpty) _buildSocialBadge(Icons.alternate_email, "Twitter", twitterUrl),
                                    if (instagramUrl.isNotEmpty) _buildSocialBadge(Icons.camera_alt, "Instagram", instagramUrl),
                                    if (emailUrl.isNotEmpty) _buildSocialBadge(Icons.email, "Email", "mailto:$emailUrl"),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- ADD SECTION BUTTON FOR OWNER ---
                      if (isOwner) ...[
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.playlist_add_rounded, size: 18),
                            label: const Text("Add New Portfolio Section", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            onPressed: () => _showSectionDialog(context),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      // --- DYNAMIC SECTIONS STREAM ---
                      StreamBuilder<QuerySnapshot>(
                        stream: db.collection('sections').orderBy('createdAt', descending: false).snapshots(),
                        builder: (context, sectionsSnapshot) {
                          if (!sectionsSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                          }

                          final sectionDocs = sectionsSnapshot.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sectionDocs.length,
                            itemBuilder: (context, sectionIndex) {
                              final sectionDoc = sectionDocs[sectionIndex];
                              final sectionData = sectionDoc.data() as Map<String, dynamic>;
                              final sectionTitle = sectionData['title'] ?? 'Section';
                              
                              Uint8List? headerIconBytes;
                              if (sectionData['headerIconBase64'] != null) {
                                try {
                                  headerIconBytes = base64Decode(sectionData['headerIconBase64']);
                                } catch (_) {}
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 35),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // SECTION HEADER
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                image: headerIconBytes != null ? DecorationImage(image: MemoryImage(headerIconBytes), fit: BoxFit.cover) : null,
                                              ),
                                              child: headerIconBytes == null
                                                  ? const Icon(Icons.rocket_launch_rounded, color: Color(0xFF6366F1), size: 16)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              sectionTitle,
                                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                          ],
                                        ),
                                        if (isOwner)
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, color: Colors.amberAccent, size: 18),
                                                tooltip: "Edit Section Header",
                                                onPressed: () => _showSectionDialog(context, doc: sectionDoc),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                                tooltip: "Delete Section",
                                                onPressed: () async {
                                                  final items = await db.collection('section_items').where('sectionId', isEqualTo: sectionDoc.id).get();
                                                  for (var item in items.docs) {
                                                    await item.reference.delete();
                                                  }
                                                  await sectionDoc.reference.delete();
                                                },
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF6366F1),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.add_rounded, size: 14),
                                                label: const Text("Add Item", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                onPressed: () => _showItemDialog(context, sectionDoc.id),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // SECTION ITEMS STREAM
                                    StreamBuilder<QuerySnapshot>(
                                      stream: db.collection('section_items').where('sectionId', isEqualTo: sectionDoc.id).snapshots(),
                                      builder: (context, itemsSnapshot) {
                                        if (!itemsSnapshot.hasData || itemsSnapshot.data!.docs.isEmpty) {
                                          return Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF121620) : Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                            ),
                                            child: Text(
                                              "No items added to $sectionTitle yet.",
                                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                                            ),
                                          );
                                        }

                                        final itemDocs = itemsSnapshot.data!.docs;

                                        return ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: itemDocs.length,
                                          itemBuilder: (context, itemIndex) {
                                            final itemDoc = itemDocs[itemIndex];
                                            final itemData = itemDoc.data() as Map<String, dynamic>;
                                            final linkText = itemData['link'] ?? '';

                                            Uint8List? iconBytes;
                                            if (itemData['iconBase64'] != null) {
                                              try {
                                                iconBytes = base64Decode(itemData['iconBase64']);
                                              } catch (_) {}
                                            }

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF121620) : Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.05),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6366F1).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                      image: iconBytes != null ? DecorationImage(image: MemoryImage(iconBytes), fit: BoxFit.cover) : null,
                                                    ),
                                                    child: iconBytes == null
                                                        ? const Icon(Icons.web_rounded, color: Color(0xFF818CF8), size: 22)
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          itemData['title'] ?? '',
                                                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          itemData['description'] ?? '',
                                                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, height: 1.4),
                                                        ),
                                                        if (linkText.isNotEmpty) ...[
                                                          const SizedBox(height: 8),
                                                          InkWell(
                                                            onTap: () => _launchUrl(linkText),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF818CF8)),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    linkText,
                                                                    style: const TextStyle(
                                                                      color: Color(0xFF818CF8),
                                                                      fontSize: 12,
                                                                      fontWeight: FontWeight.w500,
                                                                      decoration: TextDecoration.underline,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ]
                                                      ],
                                                    ),
                                                  ),
                                                  if (isOwner)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_rounded, color: Colors.amberAccent, size: 18),
                                                          tooltip: "Edit Item",
                                                          onPressed: () => _showItemDialog(context, sectionDoc.id, doc: itemDoc),
                                                          constraints: const BoxConstraints(),
                                                          padding: const EdgeInsets.all(4),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                                                          tooltip: "Delete Item",
                                                          onPressed: () async {
                                                            await db.collection('section_items').doc(itemDoc.id).delete();
                                                          },
                                                          constraints: const BoxConstraints(),
                                                          padding: const EdgeInsets.all(4),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // --- FOOTER ---
                      const SizedBox(height: 40),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          "© ${DateTime.now().year} Danny Fareez. All rights reserved.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}