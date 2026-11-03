import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:jamiat/src/data/apis/upload_api.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/location_model.dart';
import 'package:jamiat/src/data/models/user_model.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/secure_storage_service.dart';
import 'package:jamiat/src/data/utils/auth_navigation.dart';
import 'package:jamiat/src/data/services/deep_link_service.dart';
import 'package:flutter_countries/flutter_countries.dart' as fc;
import 'package:jamiat/src/data/providers/location_provider.dart';
import 'package:jamiat/src/interfaces/components/loading_indicator.dart';
import 'package:jamiat/src/interfaces/components/modal_sheet.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';
import 'package:jamiat/src/interfaces/components/profile_avatar.dart';
import 'package:jamiat/src/interfaces/onboarding/role_selection.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.isEditMode = false});

  final bool isEditMode;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const double _figmaWidth = 402;
  static const double _fieldHeight = 66;
  static const double _fieldGap = 16;
  static const double _labelGap = 8;
  static const double _avatarSize = 120;
  static const double _cameraBadgeSize = 32;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;

  late FocusNode _whatsappFocusNode;

  bool _sameAsPhoneNumber = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _didPrefill = false;
  bool _attemptedSubmit = false;
  String _verifiedPhone = '';
  String _whatsappFullNumber = '';
  String? _imageUrl;
  String? _existingRole;

  String? _selectedGender;
  String? _selectedArea;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  int? _selectedStateId;
  String? _selectedStateCode;
  String? _selectedStateName;
  String? _selectedDistrictCode;
  String? _selectedDistrictName;

  /// Mongo district `_id` when using Jamiat `/location/districts` (Kerala).
  String? _selectedBackendDistrictId;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  bool get _isKeralaSelected {
    final state = _selectedStateName?.trim().toLowerCase();
    return state == 'kerala';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _addressController = TextEditingController();
    _pincodeController = TextEditingController();

    _whatsappFocusNode = FocusNode();
    _loadVerifiedPhone();

    _phoneController.addListener(() {
      if (_sameAsPhoneNumber) {
        _whatsappController.text = _phoneController.text;
      }
    });
  }

  Future<void> _loadVerifiedPhone() async {
    final phone = await ref.read(secureStorageServiceProvider).getPhone();
    if (!mounted || phone == null) return;
    setState(() {
      _verifiedPhone = phone;
      _phoneController.text = _phoneDigits(phone);
    });
  }

  String _phoneDigits(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length > 10 && cleaned.startsWith('91')) {
      return cleaned.substring(cleaned.length - 10);
    }
    return cleaned;
  }

  void _ensureInList(List<String> list, String? value) {
    if (value == null || value.isEmpty) return;
    if (!list.contains(value)) list.add(value);
  }

  String? _capitalizeGender(String? gender) {
    if (gender == null || gender.isEmpty) return null;
    return '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}';
  }

  String _formatDob(DateTime? dob) {
    if (dob == null) return '';
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    return '$day/$month/${dob.year}';
  }

  void _prefillFromUser(UserModel user) {
    if (_didPrefill) return;
    _didPrefill = true;

    final gender = _capitalizeGender(user.gender);
    _ensureInList(_genders, gender);

    _nameController.text = user.name ?? '';
    _emailController.text = user.email ?? '';
    _addressController.text = user.address ?? '';
    _selectedArea = user.area;
    _pincodeController.text = user.pincode?.toString() ?? '';
    _dobController.text = _formatDob(user.dob);
    _imageUrl = user.image;
    _existingRole = user.role;

    final phone = user.phone.isNotEmpty ? user.phone : _verifiedPhone;
    _verifiedPhone = phone;
    _phoneController.text = _phoneDigits(phone);

    final whatsapp = user.whatsappNo ?? '';
    final sameAsPhone = whatsapp.isEmpty || whatsapp == phone;
    _sameAsPhoneNumber = sameAsPhone;
    if (sameAsPhone) {
      _whatsappController.text = phone;
      _whatsappFullNumber = phone;
    } else {
      _whatsappController.text = whatsapp.replaceFirst(
        RegExp(r'^\+\d{1,3}'),
        '',
      );
      _whatsappFullNumber = whatsapp;
    }

    _selectedGender = gender;
    _selectedCountryName = user.country;
    _selectedStateName = user.state;
    _selectedDistrictName = user.district;

    if (user.role.isNotEmpty) {
      ref.read(selectedRoleProvider.notifier).setRole(user.role);
    }

    _resolveLocationCodesFromNames();
  }

  Future<void> _resolveLocationCodesFromNames() async {
    if ((_selectedCountryName == null || _selectedCountryName!.isEmpty) &&
        _selectedCountryCode == null) {
      return;
    }

    final countries = await fc.Countries.all;
    fc.Country? country;
    for (final item in countries) {
      final matchesCode = item.iso2 == _selectedCountryCode;
      final matchesName =
          item.name?.toLowerCase() == _selectedCountryName?.toLowerCase();
      if (matchesCode || matchesName) {
        country = item;
        break;
      }
    }
    if (country == null || country.iso2 == null || !mounted) return;

    final resolvedCountry = country;
    final countryIso2 = resolvedCountry.iso2!;

    setState(() {
      _selectedCountryCode = countryIso2;
      _selectedCountryName = resolvedCountry.name;
    });

    if ((_selectedStateName == null || _selectedStateName!.isEmpty) &&
        _selectedStateCode == null) {
      return;
    }

    final states = await fc.States.byCountryCode(countryIso2);
    fc.State? state;
    for (final item in states) {
      if (item.countryCode != countryIso2) continue;
      final matchesCode = item.stateCode.toString() == _selectedStateCode;
      final matchesName =
          item.name?.toLowerCase() == _selectedStateName?.toLowerCase();
      if (matchesCode || matchesName) {
        state = item;
        break;
      }
    }
    if (state == null || !mounted) return;

    final resolvedState = state;
    setState(() {
      _selectedStateId = resolvedState.id;
      _selectedStateCode = resolvedState.stateCode.toString();
      _selectedStateName = resolvedState.name;
    });

    if ((_selectedDistrictName == null || _selectedDistrictName!.isEmpty) &&
        _selectedDistrictCode == null) {
      await _resolveBackendDistrictId();
      return;
    }

    // Kerala districts + areas come from Jamiat backend — skip offline cities.
    if (_isKeralaSelected) {
      await _resolveBackendDistrictId();
      return;
    }

    // Scope cities to this state's unique id — state codes collide globally.
    final stateId = resolvedState.id;
    final stateCode = resolvedState.stateCode;
    final List<fc.City> cities;
    if (stateId != null) {
      cities = (await fc.Cities.byStateId(
        stateId.toString(),
      )).where((city) => city.stateId == stateId).toList();
    } else {
      cities = (await fc.Cities.byStateCode(stateCode.toString()))
          .where(
            (city) =>
                city.stateCode == stateCode && city.countryCode == countryIso2,
          )
          .toList();
    }
    fc.City? city;
    for (final item in cities) {
      final matchesCode = item.id.toString() == _selectedDistrictCode;
      final matchesName =
          item.name?.toLowerCase() == _selectedDistrictName?.toLowerCase();
      if (matchesCode || matchesName) {
        city = item;
        break;
      }
    }
    if (city == null || !mounted) return;

    setState(() {
      _selectedDistrictCode = city!.id.toString();
      _selectedDistrictName = city.name;
      _selectedBackendDistrictId = null;
    });
  }

  /// Maps the selected district name to a Mongo district id when Kerala areas apply.
  Future<void> _resolveBackendDistrictId() async {
    if (!_isKeralaSelected ||
        _selectedDistrictName == null ||
        _selectedDistrictName!.trim().isEmpty) {
      if (mounted) {
        setState(() => _selectedBackendDistrictId = null);
      }
      return;
    }

    try {
      final districts = await ref.read(backendDistrictsProvider.future);
      LocationDistrict? match;
      final target = _selectedDistrictName!.trim().toLowerCase();
      for (final district in districts) {
        if (district.name.toLowerCase() == target) {
          match = district;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        if (match != null) {
          _selectedBackendDistrictId = match.id;
          _selectedDistrictCode = match.id;
          _selectedDistrictName = match.name;
        } else {
          _selectedBackendDistrictId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _selectedBackendDistrictId = null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _whatsappFocusNode.dispose();
    super.dispose();
  }

  OutlineInputBorder _fieldBorder({Color? color, double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(kCardRadiusLg),
      borderSide: BorderSide(color: color ?? kBorder, width: width),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    String? errorText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: kWhite,
      hintText: hintText,
      // height: 1.0 removes Flutter's default line-height leading so the hint
      // glyph sits at the same optical baseline as typed input text.
      hintStyle: kBodyTitleR.copyWith(color: kSecondaryTextColor, height: 1.0),
      errorText: errorText,
      errorStyle: kCaption12R.copyWith(color: kRed, height: 1.2),
      errorMaxLines: 2,
      // vertical: 25 centres a 15 sp glyph (height:1.0 → 15 px) inside the
      // 66 px minHeight field: (66 - 15) / 2 ≈ 25.5 → 25.
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(vertical: 25, horizontal: 24),
      // Keep field height; do not wrap the FormField in a fixed SizedBox or
      // error text below the input gets clipped.
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      border: _fieldBorder(),
      enabledBorder: _fieldBorder(),
      focusedBorder: _fieldBorder(color: kPrimaryColor, width: 1.5),
      errorBorder: _fieldBorder(color: kRed, width: 1.5),
      focusedErrorBorder: _fieldBorder(color: kRed, width: 2),
      suffixIcon: suffixIcon,
    );
  }

  /// Inline error for required dropdowns after the user taps Continue.
  String? _requiredSelectionError(String? value, String message) {
    if (!_attemptedSubmit) return null;
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? get _whatsappError {
    if (!_attemptedSubmit) return null;
    final whatsapp = _sameAsPhoneNumber ? _verifiedPhone : _whatsappFullNumber;
    if (whatsapp.trim().isEmpty) return 'WhatsApp number is required';
    return null;
  }

  bool get _areRequiredSelectionsValid {
    return [
      _selectedGender,
      _selectedCountryName,
      _selectedStateName,
      _selectedDistrictName,
      _selectedArea,
    ].every((value) => value != null && value.trim().isNotEmpty);
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _labelGap),
      child: Text.rich(
        TextSpan(
          text: text,
          style: kLabel15M.copyWith(height: 1.2),
          children: [
            TextSpan(
              text: ' *',
              style: kLabel15M.copyWith(color: kRed, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntlPhoneField({
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
    FocusNode? focusNode,
    String? errorText,
    void Function(String completeNumber)? onChanged,
  }) {
    return IntlPhoneField(
      focusNode: focusNode,
      controller: controller,
      initialCountryCode: 'IN',
      disableLengthCheck: true,
      showCountryFlag: false,
      showDropdownIcon: true,
      enabled: enabled,
      cursorColor: kBlack,
      style: kBodyTitleR.copyWith(
        color: enabled ? kTextColor : kSecondaryTextColor,
      ),
      dropdownTextStyle: kBodyTitleR.copyWith(
        color: enabled ? kTextColor : kSecondaryTextColor,
      ),
      dropdownIcon: const Icon(
        Icons.keyboard_arrow_down,
        color: kSecondaryTextColor,
        size: 20,
      ),
      dropdownIconPosition: IconPosition.trailing,
      flagsButtonPadding: const EdgeInsets.only(left: 18, right: 8),
      decoration: _inputDecoration(hintText: hintText, errorText: errorText),
      onCountryChanged: (_) {},
      onChanged: (phone) {
        onChanged?.call(phone.completeNumber.replaceAll(' ', ''));
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          // height: 1.0 keeps the typed-text baseline aligned with the hint.
          style: kBodyTitleR.copyWith(
            color: enabled ? kTextColor : kSecondaryTextColor,
            height: 1.0,
          ),
          validator: validator,
          decoration: _inputDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _buildSelectField({
    required String label,
    required String? value,
    required String hintText,
    required VoidCallback? onTap,
    bool isLoading = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        GestureDetector(
          onTap: onTap,
          child: InputDecorator(
            decoration: _inputDecoration(
              hintText: hintText,
              errorText: errorText,
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: LoadingAnimation(size: 20),
                    )
                  : const Icon(
                      Icons.keyboard_arrow_down,
                      color: kSecondaryTextColor,
                      size: 20,
                    ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value ?? hintText,
                style: kBodyTitleR.copyWith(
                  color: value == null ? kSecondaryTextColor : kTextColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return _buildSelectField(
      label: 'Gender',
      value: _selectedGender,
      hintText: 'Select',
      errorText: _requiredSelectionError(_selectedGender, 'Gender is required'),
      onTap: () {
        ModalSheet<String>(
          context: context,
          title: 'Select gender',
          searchHint: 'Search gender',
          items: _genders,
          itemLabel: (value) => value,
          onItemSelected: (value) {
            setState(() => _selectedGender = value);
          },
        ).show();
      },
    );
  }

  Widget _buildAreaField() {
    return Consumer(
      builder: (context, ref, _) {
        final districtName = _selectedDistrictName?.trim();
        final hasDistrict = districtName != null && districtName.isNotEmpty;

        if (!hasDistrict) {
          return _buildSelectField(
            label: 'Area',
            value: null,
            hintText: 'Select district first',
            onTap: null,
            errorText: _requiredSelectionError(
              _selectedArea,
              'Area is required',
            ),
          );
        }

        final areasAsync = ref.watch(
          getAreasByDistrictProvider((
            districtId: _selectedBackendDistrictId,
            districtName: districtName,
          )),
        );

        return areasAsync.when(
          data: (areas) {
            final areaNames = areas.map((a) => a.name).toList();
            if (areaNames.isEmpty) {
              return _buildSelectField(
                label: 'Area',
                value: _selectedArea,
                hintText: 'Select',
                onTap: null,
                errorText: 'No areas available for this district',
              );
            }

            return _buildSelectField(
              label: 'Area',
              value: _selectedArea,
              hintText: 'Select',
              errorText: _requiredSelectionError(
                _selectedArea,
                'Area is required',
              ),
              onTap: () {
                ModalSheet<String>(
                  context: context,
                  title: 'Select area',
                  searchHint: 'Search area',
                  items: areaNames,
                  itemLabel: (value) => value,
                  searchFilter: (value, query) =>
                      value.toLowerCase().contains(query.toLowerCase()),
                  onItemSelected: (value) {
                    setState(() => _selectedArea = value);
                  },
                ).show();
              },
            );
          },
          loading: () => _buildSelectField(
            label: 'Area',
            value: _selectedArea,
            hintText: 'Select',
            onTap: null,
            isLoading: true,
            errorText: _requiredSelectionError(
              _selectedArea,
              'Area is required',
            ),
          ),
          error: (error, _) => _buildSelectField(
            label: 'Area',
            value: _selectedArea,
            hintText: 'Select',
            onTap: null,
            errorText: 'Unable to load areas',
          ),
        );
      },
    );
  }

  Widget _buildCountryField() {
    return Consumer(
      builder: (context, ref, _) {
        final countriesAsync = ref.watch(getAllCountriesProvider);
        return countriesAsync.when(
          data: (countries) {
            final countryMap = {
              for (final country in countries)
                if ((country.iso2 ?? '').isNotEmpty)
                  country.iso2!: country.name ?? '',
            };
            return _buildSelectField(
              label: 'Country',
              value: _selectedCountryName,
              hintText: 'Select',
              errorText: _requiredSelectionError(
                _selectedCountryName,
                'Country is required',
              ),
              onTap: () {
                ModalSheet<String>(
                  context: context,
                  title: 'Select country',
                  searchHint: 'Search country',
                  items: countryMap.keys.toList(),
                  itemLabel: (code) => countryMap[code] ?? code,
                  searchFilter: (code, query) {
                    final name = countryMap[code] ?? '';
                    final q = query.toLowerCase();
                    return name.toLowerCase().contains(q) ||
                        code.toLowerCase().contains(q);
                  },
                  onItemSelected: (code) {
                    setState(() {
                      _selectedCountryCode = code;
                      _selectedCountryName = countryMap[code];
                      _selectedStateId = null;
                      _selectedStateCode = null;
                      _selectedStateName = null;
                      _selectedDistrictCode = null;
                      _selectedDistrictName = null;
                      _selectedBackendDistrictId = null;
                      _selectedArea = null;
                    });
                  },
                ).show();
              },
            );
          },
          loading: () => _buildSelectField(
            label: 'Country',
            value: _selectedCountryName,
            hintText: 'Select',
            onTap: null,
            isLoading: true,
            errorText: _requiredSelectionError(
              _selectedCountryName,
              'Country is required',
            ),
          ),
          error: (error, _) => _buildSelectField(
            label: 'Country',
            value: _selectedCountryName,
            hintText: 'Select',
            onTap: null,
            errorText: 'Unable to load countries',
          ),
        );
      },
    );
  }

  Widget _buildStateField() {
    return Consumer(
      builder: (context, ref, _) {
        if (_selectedCountryCode == null) {
          return _buildSelectField(
            label: 'State',
            value: null,
            hintText: 'Select',
            onTap: null,
            errorText: _requiredSelectionError(
              _selectedStateName,
              'State is required',
            ),
          );
        }

        final statesAsync = ref.watch(
          getStatesByCountryProvider(_selectedCountryCode!),
        );
        return statesAsync.when(
          data: (states) {
            // Key by unique state id — state codes collide across countries
            // and can even collide within poorly curated datasets.
            final stateById = {
              for (final state in states)
                if (state.id != null) state.id!.toString(): state,
            };
            return _buildSelectField(
              label: 'State',
              value: _selectedStateName,
              hintText: 'Select',
              errorText: _requiredSelectionError(
                _selectedStateName,
                'State is required',
              ),
              onTap: () {
                ModalSheet<String>(
                  context: context,
                  title: 'Select state',
                  searchHint: 'Search state',
                  items: stateById.keys.toList(),
                  itemLabel: (id) => stateById[id]?.name ?? id,
                  searchFilter: (id, query) {
                    final state = stateById[id];
                    final name = state?.name ?? '';
                    final code = state?.stateCode ?? '';
                    final q = query.toLowerCase();
                    return name.toLowerCase().contains(q) ||
                        code.toLowerCase().contains(q);
                  },
                  onItemSelected: (id) {
                    final state = stateById[id];
                    setState(() {
                      _selectedStateId = state?.id;
                      _selectedStateCode = state?.stateCode?.toString();
                      _selectedStateName = state?.name;
                      _selectedDistrictCode = null;
                      _selectedDistrictName = null;
                      _selectedBackendDistrictId = null;
                      _selectedArea = null;
                    });
                  },
                ).show();
              },
            );
          },
          loading: () => _buildSelectField(
            label: 'State',
            value: _selectedStateName,
            hintText: 'Select',
            onTap: null,
            isLoading: true,
            errorText: _requiredSelectionError(
              _selectedStateName,
              'State is required',
            ),
          ),
          error: (error, _) => _buildSelectField(
            label: 'State',
            value: _selectedStateName,
            hintText: 'Select',
            onTap: null,
            errorText: 'Unable to load states',
          ),
        );
      },
    );
  }

  Widget _buildDistrictField() {
    return Consumer(
      builder: (context, ref, _) {
        if (_selectedCountryCode == null ||
            (_selectedStateId == null &&
                (_selectedStateCode == null || _selectedStateCode!.isEmpty))) {
          return _buildSelectField(
            label: 'District',
            value: null,
            hintText: 'Select',
            onTap: null,
            errorText: _requiredSelectionError(
              _selectedDistrictName,
              'District is required',
            ),
          );
        }

        // Kerala areas are keyed to Mongo districts — use backend list so names/IDs match.
        if (_isKeralaSelected) {
          final districtsAsync = ref.watch(backendDistrictsProvider);
          return districtsAsync.when(
            data: (districts) {
              final districtMap = {
                for (final district in districts) district.id: district.name,
              };
              return _buildSelectField(
                label: 'District',
                value: _selectedDistrictName,
                hintText: 'Select',
                errorText: _requiredSelectionError(
                  _selectedDistrictName,
                  'District is required',
                ),
                onTap: () {
                  ModalSheet<String>(
                    context: context,
                    title: 'Select district',
                    searchHint: 'Search district',
                    items: districtMap.keys.toList(),
                    itemLabel: (id) => districtMap[id] ?? id,
                    searchFilter: (id, query) {
                      final name = districtMap[id] ?? '';
                      return name.toLowerCase().contains(query.toLowerCase());
                    },
                    onItemSelected: (id) {
                      setState(() {
                        _selectedBackendDistrictId = id;
                        _selectedDistrictCode = id;
                        _selectedDistrictName = districtMap[id];
                        _selectedArea = null;
                      });
                    },
                  ).show();
                },
              );
            },
            loading: () => _buildSelectField(
              label: 'District',
              value: _selectedDistrictName,
              hintText: 'Select',
              onTap: null,
              isLoading: true,
              errorText: _requiredSelectionError(
                _selectedDistrictName,
                'District is required',
              ),
            ),
            error: (error, _) => _buildSelectField(
              label: 'District',
              value: _selectedDistrictName,
              hintText: 'Select',
              onTap: null,
              errorText: 'Unable to load districts',
            ),
          );
        }

        final districtsAsync = ref.watch(
          getDistrictsByStateProvider((
            countryCode: _selectedCountryCode!,
            stateCode: _selectedStateCode ?? '',
            stateId: _selectedStateId,
          )),
        );
        return districtsAsync.when(
          data: (districts) {
            final districtMap = {
              for (final district in districts)
                district.id.toString(): district.name ?? '',
            };
            return _buildSelectField(
              label: 'District',
              value: _selectedDistrictName,
              hintText: 'Select',
              errorText: _requiredSelectionError(
                _selectedDistrictName,
                'District is required',
              ),
              onTap: () {
                ModalSheet<String>(
                  context: context,
                  title: 'Select district',
                  searchHint: 'Search district',
                  items: districtMap.keys.toList(),
                  itemLabel: (id) => districtMap[id] ?? id,
                  searchFilter: (id, query) {
                    final name = districtMap[id] ?? '';
                    return name.toLowerCase().contains(query.toLowerCase());
                  },
                  onItemSelected: (id) {
                    setState(() {
                      _selectedBackendDistrictId = null;
                      _selectedDistrictCode = id;
                      _selectedDistrictName = districtMap[id];
                      _selectedArea = null;
                    });
                  },
                ).show();
              },
            );
          },
          loading: () => _buildSelectField(
            label: 'District',
            value: _selectedDistrictName,
            hintText: 'Select',
            onTap: null,
            isLoading: true,
            errorText: _requiredSelectionError(
              _selectedDistrictName,
              'District is required',
            ),
          ),
          error: (error, _) => _buildSelectField(
            label: 'District',
            value: _selectedDistrictName,
            hintText: 'Select',
            onTap: null,
            errorText: 'Unable to load districts',
          ),
        );
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: kBodyTitleR.copyWith(color: kTextColor),
          decoration: _inputDecoration(hintText: 'dd/mm/yyyy'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Date of birth is required';
            }
            final parts = value.trim().split('/');
            if (parts.length != 3) {
              return 'Enter a valid date of birth';
            }
            return null;
          },
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(now.year - 18),
              firstDate: DateTime(1920),
              lastDate: now,
              locale: const Locale('en', 'IN'),
              initialEntryMode: DatePickerEntryMode.calendarOnly,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: kPrimaryColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              final day = picked.day.toString().padLeft(2, '0');
              final month = picked.month.toString().padLeft(2, '0');
              final year = picked.year.toString();
              setState(() {
                controller.text = '$day/$month/$year';
              });
            }
          },
        ),
      ],
    );
  }

  bool get _hasProfilePhoto {
    final url = _imageUrl?.trim();
    return url != null && url.isNotEmpty && url.startsWith('http');
  }

  Future<void> _onAvatarTap() async {
    if (_isUploadingAvatar) return;

    if (!_hasProfilePhoto) {
      await _pickAndUploadAvatar();
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: kTextColor,
                ),
                title: Text(
                  'Change photo',
                  style: kBodyTitleR.copyWith(color: kTextColor),
                ),
                onTap: () => Navigator.pop(sheetContext, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: kRed),
                title: Text(
                  'Remove photo',
                  style: kBodyTitleR.copyWith(color: kRed),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
              ListTile(
                title: Text(
                  'Cancel',
                  style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                  textAlign: TextAlign.center,
                ),
                onTap: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'change') {
      await _pickAndUploadAvatar();
    } else if (action == 'remove') {
      await _removeAvatar();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'avatar.jpg';
      final mimeType = filename.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final upload = await ref
          .read(uploadApiProvider)
          .uploadImage(
            bytes: Uint8List.fromList(bytes),
            filename: filename,
            mimeType: mimeType,
          );

      if (!mounted) return;
      if (!upload.success || upload.data == null) {
        _showMessage(upload.message ?? 'Unable to upload image.');
        return;
      }

      final imageUrl = upload.data!;
      if (widget.isEditMode) {
        final update = await ref.read(userApiProvider).updateProfile({
          'image': imageUrl,
        });
        if (!mounted) return;
        if (!update.success) {
          _showMessage(update.message ?? 'Unable to update avatar.');
          return;
        }
        ref.invalidate(userProfileProvider);
      }

      setState(() => _imageUrl = imageUrl);
      _showMessage('Avatar updated.');
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_isUploadingAvatar || !_hasProfilePhoto) return;

    // Confirm — accidental remove is hard to undo without re-uploading.
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
          'Your profile will show the default avatar until you add a new photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;

    // Always PATCH image:null so a prefilled/server photo is cleared even
    // during first-time Profile Setup (not only Edit Profile).
    setState(() => _isUploadingAvatar = true);
    try {
      final update = await ref.read(userApiProvider).updateProfile({
        'image': null,
      });
      if (!mounted) return;
      if (!update.success) {
        _showMessage(update.message ?? 'Unable to remove avatar.');
        return;
      }
      ref.invalidate(userProfileProvider);
      setState(() => _imageUrl = null);
      _showMessage('Avatar removed.');
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleContinue() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    final role = ref.read(selectedRoleProvider) ?? _existingRole;
    if (role == null || role.isEmpty) {
      _showMessage('Please select your membership role.');
      return;
    }

    setState(() => _attemptedSubmit = true);

    final formValid = _formKey.currentState!.validate();
    final selectionsValid = _areRequiredSelectionsValid;
    final whatsappValid = _whatsappError == null;

    // Show inline errors on every required field — not a single snackbar.
    if (!formValid || !selectionsValid || !whatsappValid) return;

    final whatsapp = _sameAsPhoneNumber ? _verifiedPhone : _whatsappFullNumber;
    final dobParts = _dobController.text.split('/');
    final pincode = int.tryParse(_pincodeController.text.trim());
    if (dobParts.length != 3 || pincode == null) {
      // Form validators should already cover this; keep a hard stop.
      return;
    }
    final dob = '${dobParts[2]}-${dobParts[1]}-${dobParts[0]}';

    setState(() => _isLoading = true);
    final payload = <String, dynamic>{
      'role': role,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'gender': _selectedGender!.toLowerCase(),
      'whatsapp_no': whatsapp,
      'address': _addressController.text.trim(),
      'area': _selectedArea!,
      'district': _selectedDistrictName!,
      'state': _selectedStateName!,
      'country': _selectedCountryName!,
      'pincode': pincode,
      'dob': dob,
      if (_imageUrl != null && _imageUrl!.isNotEmpty) 'image': _imageUrl,
    };

    final response = await ref.read(userApiProvider).updateProfile(payload);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.success) {
      _showMessage(response.message ?? 'Unable to update your profile.');
      return;
    }

    final user = response.data;
    if (user == null) {
      _showMessage('The server returned an invalid profile response.');
      return;
    }

    ref.invalidate(userProfileProvider);
    _showMessage(response.message ?? 'Profile updated successfully.');

    if (widget.isEditMode) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    final nextRoute = routeForUser(user);
    NavigationService().pushNamedAndRemoveUntil(nextRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nextRoute == 'navBar') {
        DeepLinkService.instance.markReady();
      } else {
        DeepLinkService.instance.resetReady();
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _avatarWidget() {
    return ProfileAvatar(
      imageUrl: _imageUrl,
      size: _avatarSize,
      backgroundColor: kGreyLight,
    );
  }

  Widget _buildWhatsAppCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sameAsPhoneNumber = !_sameAsPhoneNumber;
          if (_sameAsPhoneNumber) {
            _whatsappController.text = _phoneController.text;
            _whatsappFullNumber = _verifiedPhone;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: _labelGap),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _sameAsPhoneNumber ? kPrimaryColor : kBorder,
                  width: 1.5,
                ),
                color: _sameAsPhoneNumber ? kPrimaryColor : Colors.transparent,
              ),
              child: _sameAsPhoneNumber
                  ? const Icon(Icons.check, size: 16, color: kWhite)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Same as phone number',
              style: kCaption12R.copyWith(color: kTextColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditMode) {
      ref.listen(userProfileProvider, (previous, next) {
        next.whenData(_prefillFromUser);
      });
      final profile = ref.watch(userProfileProvider).value;
      if (profile != null && !_didPrefill) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _prefillFromUser(profile));
        });
      }
    }

    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scale = (size.width / _figmaWidth).clamp(0.88, 1.12);
    final topPadding = size.height * (70 / 874);
    final sideInset = 24 * scale;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            sideInset,
            topPadding,
            sideInset,
            24 * scale + bottomInset,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: _attemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kWhite,
                      border: Border.all(color: kBorder, width: 1.25),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: kTextColor,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(height: 32 * scale),
                Text(
                  widget.isEditMode ? 'Edit profile' : 'Profile setup',
                  style: widget.isEditMode
                      ? kHeadTitleSB.copyWith(
                          color: kTextColor,
                          fontSize: kSize23,
                          height: 27 / kSize23,
                        )
                      : kSubHeadingSB.copyWith(color: kTextColor, height: 1.4),
                ),
                Text(
                  widget.isEditMode
                      ? 'Update your details and keep your community profile current.'
                      : 'Complete your details to connect with the community and access your services.',
                  style: kCaption13R.copyWith(
                    color: kSecondaryTextColor,
                    // Keep 120% line-height so wrapped heading lines do not
                    // pick up extra leading between "Complete your details…"
                    // and "…community and access…".
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 16 * scale),
                Center(
                  child: SizedBox(
                    width: _avatarSize,
                    height: _avatarSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _avatarWidget(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _onAvatarTap,
                            child: Container(
                              width: _cameraBadgeSize,
                              height: _cameraBadgeSize,
                              decoration: const BoxDecoration(
                                color: kBlack,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _isUploadingAvatar
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: kWhite,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: kWhite,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16 * scale),
                _buildTextField(
                  label: 'Name',
                  controller: _nameController,
                  hintText: 'Enter name',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: _fieldGap),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Phone Number'),
                    _buildIntlPhoneField(
                      controller: _phoneController,
                      hintText: '999587XXXX',
                      enabled: false,
                    ),
                  ],
                ),
                const SizedBox(height: _fieldGap),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('WhatsApp Number'),
                    _buildWhatsAppCheckbox(),
                    _buildIntlPhoneField(
                      focusNode: _whatsappFocusNode,
                      controller: _whatsappController,
                      hintText: 'Enter mobile number',
                      enabled: !_sameAsPhoneNumber,
                      errorText: _whatsappError,
                      onChanged: (value) {
                        setState(() => _whatsappFullNumber = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: _fieldGap),
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'Enter email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val != null &&
                        val.trim().isNotEmpty &&
                        !RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(val.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: _fieldGap),
                _buildGenderField(),
                const SizedBox(height: _fieldGap),
                _buildDateField(
                  label: 'Date of Birth',
                  controller: _dobController,
                  context: context,
                ),
                const SizedBox(height: _fieldGap),
                _buildTextField(
                  label: 'Address',
                  controller: _addressController,
                  hintText: 'Enter Address',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: _fieldGap),
                _buildCountryField(),
                const SizedBox(height: _fieldGap),
                _buildStateField(),
                const SizedBox(height: _fieldGap),
                _buildDistrictField(),
                const SizedBox(height: _fieldGap),
                _buildAreaField(),
                const SizedBox(height: _fieldGap),
                _buildTextField(
                  label: 'Pin code',
                  controller: _pincodeController,
                  hintText: 'Enter pin code',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Pin code is required';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'Enter a valid pin code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                primaryButton(
                  label: widget.isEditMode ? 'Save changes' : 'Continue',
                  onPressed: _isLoading ? null : _handleContinue,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
