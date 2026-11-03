import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:jamiat/src/data/apis/auth_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/user_model.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/secure_storage_service.dart';
import 'package:jamiat/src/data/services/deep_link_service.dart';
import 'package:jamiat/src/data/services/get_fcm.dart';
import 'package:jamiat/src/data/utils/auth_navigation.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum _OtpChannel { sms, whatsapp }

// ================= MAIN LOGIN SCREEN =================

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _phoneController;
  late FocusNode _phoneFocusNode;
  bool _isLoading = false;
  bool _showPhoneError = false;
  String _fullPhoneNumber = '';
  String _dialCode = '91';
  _OtpChannel _otpChannel = _OtpChannel.sms;

  bool get _isIndianNumber => _dialCode == '91';

  String get _otpVia => _isIndianNumber && _otpChannel == _OtpChannel.whatsapp
      ? 'whatsapp'
      : 'sms';

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() => _showPhoneError = true);

    final digits = _phoneController.text.trim();
    if (digits.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(digits)) {
      _showMessage('Please enter a valid mobile number');
      return;
    }
    if (digits.length < 6 || digits.length > 14) {
      _showMessage('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    final phone = _fullPhoneNumber.isNotEmpty
        ? _fullPhoneNumber.replaceAll(' ', '')
        : '+$_dialCode$digits';

    final secureStorage = ref.read(secureStorageServiceProvider);
    String? fcmToken;
    try {
      final existingFcmToken = await secureStorage.getFcmToken();
      if (existingFcmToken == null || existingFcmToken.isEmpty) {
        if (!mounted) return;
        await getFcmToken(context, ref);
        if (!mounted) return;
        fcmToken = await secureStorage.getFcmToken();
      } else {
        fcmToken = existingFcmToken;
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    final otpVia = _otpVia;
    final response = await ref
        .read(authApiProvider)
        .requestOtp(phone: phone, otpVia: otpVia, fcm: fcmToken);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.success) {
      _showMessage(response.message ?? 'Unable to send OTP.');
      return;
    }

    _showMessage(response.message ?? 'OTP sent successfully.');
    Navigator.push(
      context,
      NavigationService().navigatAnimated(
        OTPScreen(
          phoneNumber: digits,
          dialCode: _dialCode,
          fullPhoneNumber: phone,
          otpVia: otpVia,
        ),
        fade: true,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  OutlineInputBorder _phoneBorder({Color? color, double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(kCardRadiusMd),
      borderSide: BorderSide(color: color ?? kBorder, width: width),
    );
  }

  Widget _otpChannelOption({
    required _OtpChannel channel,
    required String label,
    required String iconAsset,
    required bool isSelected,
  }) {
    final color = isSelected ? kPrimaryColor : kSecondaryTextColor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _otpChannel = channel);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor.withValues(alpha: 0.08) : kWhite,
            borderRadius: BorderRadius.circular(kCardRadiusMd),
            border: Border.all(
              color: isSelected ? kPrimaryColor : kCardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: kCaption12M.copyWith(
                  color: color,
                  fontWeight: isSelected ? kSemiBold : kMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpChannelPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receive OTP via', style: kLabel15M),
        const SizedBox(height: 8),
        Row(
          children: [
            _otpChannelOption(
              channel: _OtpChannel.sms,
              label: 'SMS',
              iconAsset: 'assets/svg/otp_sms.svg',
              isSelected: _otpChannel == _OtpChannel.sms,
            ),
            const SizedBox(width: 12),
            _otpChannelOption(
              channel: _OtpChannel.whatsapp,
              label: 'WhatsApp',
              iconAsset: 'assets/svg/otp_whatsapp.svg',
              isSelected: _otpChannel == _OtpChannel.whatsapp,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                    color: kWhite.withValues(alpha: 0.08),
                    // border: Border.all(color: kGrey, width: 1.25),
                  ),
                  // child: const Icon(
                  //   Icons.arrow_back,
                  //   color: kTextColor,
                  //   size: 20,
                  // ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 80,
                height: 80,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/svg/phonelogo.svg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verify your phone number',
                style: kSubHeadingSB.copyWith(height: 1.4),
              ),
              Text(
                "Enter the phone number you'd like to verify.",
                style: kCaption12R.copyWith(
                  color: kSecondaryTextColor,
                  height: 1.36,
                ),
              ),
              const SizedBox(height: 16),
              Text('Mobile Number', style: kLabel15M),
              const SizedBox(height: 8),
              IntlPhoneField(
                focusNode: _phoneFocusNode,
                controller: _phoneController,
                initialCountryCode: 'IN',
                disableLengthCheck: true,
                showCountryFlag: false,
                showDropdownIcon: true,
                cursorColor: kBlack,
                style: kBodyTitleR.copyWith(color: kTextColor),
                dropdownTextStyle: kBodyTitleR.copyWith(color: kTextColor),
                dropdownIcon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: kSecondaryTextColor,
                  size: 18,
                ),
                dropdownIconPosition: IconPosition.trailing,
                flagsButtonPadding: const EdgeInsets.only(left: 18),
                validator: (phone) {
                  if (!_showPhoneError) return null;
                  if (phone == null || phone.number.isEmpty) {
                    return 'Mobile number is required';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(phone.number)) {
                    return 'Mobile number must contain only digits';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kWhite,
                  hintText: 'Enter mobile number',
                  hintStyle: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  border: _phoneBorder(),
                  enabledBorder: _phoneBorder(),
                  focusedBorder: _phoneBorder(color: kPrimaryColor, width: 1.5),
                  errorBorder: _phoneBorder(color: kRed, width: 1.5),
                  focusedErrorBorder: _phoneBorder(color: kRed, width: 2),
                ),
                onCountryChanged: (value) {
                  setState(() {
                    _dialCode = value.dialCode;
                    if (_dialCode != '91') {
                      _otpChannel = _OtpChannel.sms;
                    }
                  });
                },
                onChanged: (phone) {
                  setState(() {
                    _fullPhoneNumber = phone.completeNumber;
                    _dialCode = phone.countryCode.replaceAll('+', '');
                    if (_dialCode != '91') {
                      _otpChannel = _OtpChannel.sms;
                    }
                  });
                },
              ),
              if (_isIndianNumber) ...[
                const SizedBox(height: 16),
                _buildOtpChannelPicker(),
              ],
              const SizedBox(height: 24),
              primaryButton(
                label: 'Sent OTP',
                onPressed: _isLoading ? null : _requestOtp,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= OTP SCREEN =================

class OTPScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String dialCode;
  final String fullPhoneNumber;
  final String otpVia;

  const OTPScreen({
    required this.phoneNumber,
    this.dialCode = '91',
    this.fullPhoneNumber = '',
    this.otpVia = 'sms',
    super.key,
  });

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  late TextEditingController _otpController;
  bool _isLoading = false;
  Timer? _timer;
  int _start = 59;
  bool _isResendDisabled = true;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isResendDisabled = true;
      _start = 59;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() => _isResendDisabled = false);
        timer.cancel();
      } else {
        setState(() => _start--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isLoading) return;
    _startTimer();
    setState(() => _isLoading = true);

    final response = await ref
        .read(authApiProvider)
        .requestOtp(phone: widget.fullPhoneNumber, otpVia: widget.otpVia);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.success) {
      _showMessage(response.message ?? 'Unable to resend OTP.');
      return;
    }
    _showMessage(response.message ?? 'OTP resent successfully.');
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showMessage('Please enter the 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    final response = await ref
        .read(authApiProvider)
        .verifyOtp(phone: widget.fullPhoneNumber, otp: otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!response.success) {
      _showMessage(response.message ?? 'OTP verification failed.');
      return;
    }

    final data = nestedData(response.data);
    final token = data?['token']?.toString() ?? '';
    final userJson = data?['user'];
    if (token.isEmpty || userJson is! Map) {
      _showMessage('The server returned an invalid login response.');
      return;
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    if (user.id.isEmpty) {
      _showMessage('The server returned an invalid user.');
      return;
    }

    await ref
        .read(secureStorageServiceProvider)
        .saveSession(
          token: token,
          userId: user.id,
          phone: widget.fullPhoneNumber,
        );

    if (!mounted) return;
    _showMessage(response.message ?? 'OTP verified successfully.');
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

  @override
  Widget build(BuildContext context) {
    final channelLabel = widget.otpVia == 'whatsapp' ? 'WhatsApp' : 'SMS';

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kWhite.withValues(alpha: 0.08),
                    border: Border.all(color: kGrey, width: 1.25),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: kTextColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 80,
                height: 80,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset(
                    'assets/svg/otplogo.svg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verify your phone number',
                style: kSubHeadingSB.copyWith(height: 1.4),
              ),
              Text(
                "Enter the phone number you'd like to verify.",
                style: kCaption12R.copyWith(
                  color: kSecondaryTextColor,
                  height: 1.36,
                ),
              ),
              const SizedBox(height: 16),
              Text('Enter OTP', style: kLabel15M),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  const otpLength = 6;
                  const fieldGap = 8.0;
                  final fieldWidth =
                      ((constraints.maxWidth - fieldGap * (otpLength - 1)) /
                              otpLength)
                          .clamp(44.0, 56.0);

                  return PinCodeTextField(
                    appContext: context,
                    length: otpLength,
                    controller: _otpController,
                    autoDisposeControllers: false,
                    obscureText: false,
                    autoFocus: true,
                    keyboardType: TextInputType.number,
                    animationType: AnimationType.fade,
                    textStyle: kHeadTitleSB.copyWith(
                      color: kTextColor,
                      fontSize: 20,
                    ),
                    cursorColor: kPrimaryColor,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(kCardRadiusMd),
                      fieldHeight: 58,
                      fieldWidth: fieldWidth,
                      borderWidth: 1,
                      activeBorderWidth: 1,
                      selectedBorderWidth: 2,
                      inactiveBorderWidth: 1,
                      selectedColor: kPrimaryColor,
                      activeColor: kPrimaryColor.withValues(alpha: 0.5),
                      inactiveColor: kPrimaryColor.withValues(alpha: 0.5),
                      activeFillColor: kWhite,
                      selectedFillColor: kWhite,
                      inactiveFillColor: kWhite,
                    ),
                    animationDuration: const Duration(milliseconds: 200),
                    backgroundColor: Colors.transparent,
                    enableActiveFill: true,
                    onChanged: (_) {},
                    onCompleted: (_) {
                      if (!_isLoading && mounted) {
                        _verifyOtp();
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              primaryButton(
                label: 'Verify OTP',
                onPressed: _isLoading ? null : _verifyOtp,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't get $channelLabel?",
                      style: kCaption12R.copyWith(color: kSecondaryTextColor),
                    ),
                    const SizedBox(height: 6),
                    if (_isResendDisabled)
                      RichText(
                        text: TextSpan(
                          style: kCaption12R.copyWith(
                            color: kSecondaryTextColor,
                          ),
                          children: [
                            const TextSpan(text: 'Get a new OTP in '),
                            TextSpan(
                              text: '00:${_start.toString().padLeft(2, '0')}',
                              style: kCaption12R.copyWith(
                                color: kPrimaryColor,
                                fontWeight: kSemiBold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          'Resend OTP',
                          style: kLinkSB.copyWith(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
