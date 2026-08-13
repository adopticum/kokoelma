import 'package:provider/provider.dart';
import 'package:flutter/material.dart'; //imports widgets also.
//import 'package:flutter/cupertino.dart';
import 'package:photocollectionapp/viewmodels/profile_viewmodel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();

    // Reload every time this page is mounted so changes to the profile updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileViewModel>().load();
    });
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall;
    final valueStyle = theme.textTheme.titleLarge;
    final color = theme.colorScheme.surface;

    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading && !vm.hasProfile) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!vm.hasProfile) {
          return const Center(child: Text('Failed to load profile'));
        }

        return Material(
          color: color,
          child: ListView(
            padding: const EdgeInsets.all(10.0),
            children: [
              ListTile(
                title: const Text('User ID'),
                leading: const Icon(Icons.key),
                subtitle: Text(vm.userId, overflow: TextOverflow.ellipsis),
              ),

              EditableNameField(
                label: 'Nickname',
                value: vm.nickname,
                onSave: vm.saveNickname,
                isSaving: vm.isSaving,
              ),

              EditableNameField(
                label: 'First name',
                value: vm.firstName,
                onSave: vm.saveFirstName,
                isSaving: vm.isSaving,
              ),

              EditableNameField(
                label: 'Last name',
                value: vm.lastName,
                onSave: vm.saveLastName,
                isSaving: vm.isSaving,
              ),

              /*
            ListTile(
              title: const Text('Group'),
              subtitle: Text(
                vm.group?.name ?? 'Not member of any group',
                style: valueStyle,
              ),
            ),

            ListTile(
              title: const Text('Is group admin?'),
              subtitle: Text(vm.isGroupAdmin ? "Yes" : "No", style: valueStyle),
            ),
*/
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Is group admin?', style: labelStyle),
                    const SizedBox(height: 4),
                    Text(vm.isGroupAdmin ? "Yes" : "No", style: valueStyle),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Groups', style: labelStyle),
                    const SizedBox(height: 4),
                    if (vm.groups.isEmpty)
                      Text('Not member of any group', style: valueStyle)
                    else
                      ...vm.groups.map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.group, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(group.name, style: valueStyle),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User profile',
          //style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,

      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }
}

class EditableNameField extends StatefulWidget {
  final String label;
  final String value;
  final Future<void> Function(String) onSave;
  final bool isSaving;

  const EditableNameField({
    super.key,
    required this.label,
    required this.value,
    required this.onSave,
    required this.isSaving,
  });

  @override
  State<EditableNameField> createState() => _EditableNameFieldState();
}

class _EditableNameFieldState extends State<EditableNameField> {
  bool isEditing = false;
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EditableNameField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!isEditing && (oldWidget.value != widget.value)) {
      _setControllerText(widget.value);
    }
  }

  // Set the text in a way that respects the cursor position and avoids flickering.
  void _setControllerText(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _startEditing() {
    setState(() {
      isEditing = true;
      _setControllerText(widget.value);
    });
  }

  void _cancel() {
    // Revert to VM value on cancel.
    setState(() {
      isEditing = false;
      _setControllerText(widget.value);
    });
  }

  Future<void> _save() async {
    setState(() {
      isEditing = false;
    });
    String newValue = controller.text.trim();
    if (newValue != widget.value) {
      await widget.onSave(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = Theme.of(context).textTheme.titleSmall;
    final valueStyle = Theme.of(context).textTheme.titleLarge;
    //final labelStyleDep = const TextStyle(fontSize: 12, color: Colors.grey);

    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: labelStyle),

                  const SizedBox(height: 4),

                  TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted:
                        (_) =>
                            _save(), // Trigger save on keyboard Return/Enter.
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    style: valueStyle,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            IconButton(
              onPressed: widget.isSaving ? null : _save,
              icon:
                  widget.isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.check),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),

            IconButton(
              onPressed: widget.isSaving ? null : _cancel,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: labelStyle),

                const SizedBox(height: 4),

                Text(
                  widget.value,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.isSaving ? null : _startEditing,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }
}

  /* dep.
  Widget _editableNameWidget(
    BuildContext context, {
    required String label,
    required String value,
    required bool isEditing,
    //required VoidCallback onEditStart,
    //required VoidCallback onCancel,
    required Function(String) onSave,
    required bool isLoading,
  }) {
    if (isEditing) {
      final theme = Theme.of(context);

      return Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: value,
              //onChanged: onChanged,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : onSave(value),
            icon:
                isLoading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(Icons.check),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
        ],
      );
    }

    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      trailing: IconButton(
        onPressed: onEditStart,
        icon: const Icon(Icons.edit),
      ),
    );
  }
  */




/* dep. 
class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  UserProfile? _profile;
  Group? _group;
  bool _isLoading = true;
  final _nicknameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isEditingNickname = false;
  bool _isEditingFirstName = false;
  bool _isEditingLastName = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final profile = await _profileService.getOrGenerateProfile(session.user.id);
    final group = profile != null ? await GroupService().getCurrentGroup(profile.id) : null;

    if (mounted) {
      setState(() {
        _profile = profile;
        _group = group;
        _nicknameController.text = profile?.nickname ?? '';
        _firstNameController.text = profile?.firstName ?? '';
        _lastNameController.text = profile?.lastName ?? '';
        _isLoading = false;
      });
      if (profile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
      }
    }
  }

  Future<void> _saveProfileUpdates() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = UserProfile(
        id: session.user.id,
        nickname: _nicknameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        createdAt: _profile?.createdAt,
        isAdmin: _profile?.isAdmin ?? false,
      );
      await _profileService.updateProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _isEditingNickname = false;
          _isEditingFirstName = false;
          _isEditingLastName = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildUserIdWidget() {
    return ListTile(
      dense: true,
      leading: Icon(Icons.key),
      title: Text('User ID', style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(_profile?.id ?? 'Not available'),
    );
  }

  Widget _buildEditableNameWidget({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onStartEditing,
    required VoidCallback onCancelEditing,
  }) {
    final theme = Theme.of(context);
    final value = controller.text.isNotEmpty ? controller.text : '';

    if (isEditing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _saveProfileUpdates,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
          IconButton(
            onPressed: onCancelEditing,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
        ],
      );
    }

    return ListTile(
      dense: false,
      leading: Icon(Icons.person),
      title: Text(label, style: theme.textTheme.bodySmall),
      subtitle: Text(value, style: theme.textTheme.titleMedium),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onStartEditing,
      ),
    );
  }

  Widget _buildNicknameWidget() {
    return _buildEditableNameWidget(
      label: 'Nickname',
      controller: _nicknameController,
      isEditing: _isEditingNickname,
      onStartEditing: () {
        setState(() {
          _isEditingNickname = true;
        });
      },
      onCancelEditing: () {
        setState(() {
          _isEditingNickname = false;
          _nicknameController.text = _profile?.nickname ?? '';
        });
      },
    );
  }

  Widget _buildFirstNameWidget() {
    return _buildEditableNameWidget(
      label: 'First Name',
      controller: _firstNameController,
      isEditing: _isEditingFirstName,
      onStartEditing: () {
        setState(() {
          _isEditingFirstName = true;
        });
      },
      onCancelEditing: () {
        setState(() {
          _isEditingFirstName = false;
          _firstNameController.text = _profile?.firstName ?? '';
        });
      },
    );
  }

  Widget _buildLastNameWidget() {
    return _buildEditableNameWidget(
      label: 'Last Name',
      controller: _lastNameController,
      isEditing: _isEditingLastName,
      onStartEditing: () {
        setState(() {
          _isEditingLastName = true;
        });
      },
      onCancelEditing: () {
        setState(() {
          _isEditingLastName = false;
          _lastNameController.text = _profile?.lastName ?? '';
        });
      },
    );
  }

  Widget _buildGroupWidget() {
    var theme = Theme.of(context);
    return ListTile(
      dense: false,
      leading: Icon(Icons.group),
      title: Text('Group membership', style: theme.textTheme.bodySmall),
      subtitle: Text(
        _group?.name ?? 'Not member of any group',
        style: theme.textTheme.titleMedium,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(10.0),
        children: [
          Text(
            'User Profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          _buildUserIdWidget(),
          _buildNicknameWidget(),
          _buildFirstNameWidget(),
          _buildLastNameWidget(),
          _buildGroupWidget(),
        ],
      ),
    );
  }
}
*/