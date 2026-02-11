import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/navigation/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = AppState.instance.name.value;
    _phoneController.text = AppState.instance.phone.value;
    _emailController.text = AppState.instance.extraEmail.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _isEditing = false;

  bool get _isProfileComplete {
    final name = AppState.instance.name.value;
    final phone = AppState.instance.phone.value;
    final email = AppState.instance.extraEmail.value;
    return name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;
  }

  void _saveProfile() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showError('Phone number must be exactly 10 digits');
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      _showError('Please use a valid @gmail.com address');
      return;
    }

    AppState.instance.updateProfile(
      nameVal: name,
      phoneVal: phone,
      emailVal: email,
    );

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: ValueListenableBuilder<String?>(
          valueListenable: AuthSession.instance.token,
          builder: (context, token, _) {
            final isLoggedIn = token != null && token.isNotEmpty;

            return ListenableBuilder(
              listenable: Listenable.merge([
                AppState.instance.name,
                AppState.instance.phone,
                AppState.instance.extraEmail,
              ]),
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                  children: [
                    _buildProfileHeader(isLoggedIn),
                    const SizedBox(height: 32),
                    if (isLoggedIn) ...[
                      // Show either the completion card OR the finished profile details
                      if (!_isProfileComplete || _isEditing)
                        _buildFinishProfileCard()
                      else
                        _buildCompletedProfileCard(),

                      const SizedBox(height: 24),
                      _buildSectionTitle('Preferences & App'),
                      const SizedBox(height: 12),
                      _buildSettingsCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('My Interests'),
                      const SizedBox(height: 12),
                      _buildInterestsList(),
                    ] else ...[
                      _buildLoginPrompt(context),
                    ],
                    const SizedBox(height: 40),
                    if (isLoggedIn)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await AuthSession.instance.clear();
                            await AppState.instance.clearUserProfile();
                            _nameController.clear();
                            _phoneController.clear();
                            _emailController.clear();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Signed out')),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Curate v1.0.4',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isLoggedIn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade100, width: 2),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF1A1A1A),
              child: Icon(
                isLoggedIn
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: AppState.instance.name,
              builder: (context, name, _) {
                final displayName = name.isNotEmpty
                    ? name
                    : (isLoggedIn ? 'Collector' : 'Guest Traveler');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isLoggedIn
                          ? 'Curating since Feb 2026'
                          : 'Discovering stories',
                      style: const TextStyle(
                        color: Color(0xFF7A7A7A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildInterestsList() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: AppState.instance.interests,
      builder: (context, interests, _) {
        if (interests.isEmpty) {
          return const Text('No interests selected yet.');
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: interests
              .map(
                (i) => Chip(
                  label: Text(i, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AppState.instance.isDarkMode,
            builder: (context, isDark, _) {
              return ListTile(
                leading: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: Colors.amber,
                ),
                title: const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeTrackColor: Colors.blue,
                  onChanged: (val) => AppState.instance.toggleDarkMode(val),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Private & Secure',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _nameController.text = AppState.instance.name.value;
                    _phoneController.text = AppState.instance.phone.value;
                    _emailController.text = AppState.instance.extraEmail.value;
                  });
                },
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                tooltip: 'Edit details',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.phone_rounded, AppState.instance.phone.value),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.email_rounded,
            AppState.instance.extraEmail.value,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle_rounded,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEditing ? 'Update Details' : 'Complete Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              if (_isEditing)
                IconButton(
                  onPressed: () => setState(() => _isEditing = false),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMinimalField(
            'Full Name',
            _nameController,
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          _buildMinimalField(
            'Phone Number (10 digits)',
            _phoneController,
            Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildMinimalField(
            'Gmail Address',
            _emailController,
            Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Save Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    final isPhone = label.toLowerCase().contains('phone');
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: isPhone ? 10 : null,
      inputFormatters: isPhone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textCapitalization: label.toLowerCase().contains('name')
          ? TextCapitalization.words
          : TextCapitalization.none,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
        ),
      ),
    );
  }


  Widget _buildLoginPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 40,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Discover Your Signal',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in to sync your journey, manage specialized interests, and see personal metrics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A7A7A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, routeLogin),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
