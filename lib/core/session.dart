import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../data/auth_repository.dart';

enum SessionStatus { loading, loggedOut, locked, unlocked }

/// Client mémorisé sur l'appareil après sa première connexion : l'écran de connexion
/// affiche son nom et ne demande plus que le mot de passe.
class RememberedUser {
  const RememberedUser({required this.username, required this.displayName});
  final String username;
  final String displayName;
}

/// État de session : connexion, verrouillage par PIN, biométrie.
/// Le jeton et le hash du PIN sont dans le stockage sécurisé (Keychain / Keystore).
class SessionController extends ChangeNotifier {
  SessionController({required this.auth, FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  final AuthRepository auth;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const maxPinAttempts = 5;
  static const _kToken = 'session_token';
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kBiometric = 'biometric_enabled';
  static const _kUsername = 'remembered_username';
  static const _kDisplayName = 'remembered_name';

  SessionStatus _status = SessionStatus.loading;
  SessionStatus get status => _status;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  int _failedPinAttempts = 0;
  int get pinAttemptsLeft => maxPinAttempts - _failedPinAttempts;

  /// Jeton obtenu après l'OTP, en attente de la création du PIN.
  String? _pendingToken;

  RememberedUser? _rememberedUser;
  RememberedUser? get rememberedUser => _rememberedUser;

  /// Client de la connexion en cours, mémorisé une fois la session ouverte.
  RememberedUser? _pendingUser;

  Future<void> restore() async {
    try {
      final token = await _storage.read(key: _kToken);
      final pin = await _storage.read(key: _kPinHash);
      _biometricEnabled = await _storage.read(key: _kBiometric) == 'true';
      final username = await _storage.read(key: _kUsername);
      final name = await _storage.read(key: _kDisplayName);
      _rememberedUser = username == null ? null : RememberedUser(username: username, displayName: name ?? username);
      _set(token != null && pin != null ? SessionStatus.locked : SessionStatus.loggedOut);
    } on PlatformException {
      // Stockage illisible (ex. restauration d'appareil) : on repart de zéro.
      await _storage.deleteAll();
      _set(SessionStatus.loggedOut);
    }
  }

  /// Appelé après un OTP de connexion validé ; la session s'ouvre une fois le PIN créé.
  void onLoginVerified(String token) => _pendingToken = token;

  /// Identifiants acceptés : le client sera mémorisé si la connexion aboutit (OTP + PIN).
  void setPendingUser({required String username, required String displayName}) =>
      _pendingUser = RememberedUser(username: username, displayName: displayName);

  /// « Changer de compte » : l'écran de connexion redemande l'identifiant.
  Future<void> forgetUser() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kDisplayName);
    _rememberedUser = null;
    notifyListeners();
  }

  Future<void> createPin(String pin) async {
    final token = _pendingToken;
    if (token == null) throw StateError('Aucune connexion en attente');
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: _hash(pin, salt));
    final user = _pendingUser;
    if (user != null) {
      await _storage.write(key: _kUsername, value: user.username);
      await _storage.write(key: _kDisplayName, value: user.displayName);
      _rememberedUser = user;
      _pendingUser = null;
    }
    _pendingToken = null;
    _failedPinAttempts = 0;
  }

  /// Termine l'enrôlement (après la proposition biométrique).
  void finishEnrollment() => _set(SessionStatus.unlocked);

  /// Vérifie le PIN sans changer l'état de session (ex. validation d'un virement).
  /// Après [maxPinAttempts] échecs consécutifs, la session est effacée.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt) ?? '';
    final hash = await _storage.read(key: _kPinHash);
    if (hash != null && hash == _hash(pin, salt)) {
      _failedPinAttempts = 0;
      return true;
    }
    _failedPinAttempts++;
    if (_failedPinAttempts >= maxPinAttempts) await logout();
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await verifyPin(pin);
    if (ok) _set(SessionStatus.unlocked);
    return ok;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final check = Future(() async => await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported());
      return await check.timeout(const Duration(seconds: 2), onTimeout: () => false);
    } catch (_) {
      // Plugin absent ou capteur indisponible : on se rabat sur le PIN seul.
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool value) async {
    await _storage.write(key: _kBiometric, value: value.toString());
    _biometricEnabled = value;
    notifyListeners();
  }

  /// Demande l'empreinte ou le visage, sans changer l'état de session.
  Future<bool> verifyBiometrics(String reason) async {
    if (!_biometricEnabled) return false;
    try {
      return await _localAuth.authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    final ok = await verifyBiometrics(reason);
    if (ok) _set(SessionStatus.unlocked);
    return ok;
  }

  /// Verrouille sans déconnecter (retour en arrière-plan prolongé).
  void lock() {
    if (_status == SessionStatus.unlocked) _set(SessionStatus.locked);
  }

  /// Ferme la session. Le client reste mémorisé, sauf si [forgetUser] (« Ce n'est pas vous ? »).
  Future<void> logout({bool forgetUser = false}) async {
    final token = await _storage.read(key: _kToken);
    if (token != null) {
      try {
        await auth.logout(token);
      } catch (_) {
        // La déconnexion locale doit aboutir même hors ligne.
      }
    }
    for (final key in const [_kToken, _kPinHash, _kPinSalt, _kBiometric]) {
      await _storage.delete(key: key);
    }
    if (forgetUser) {
      await _storage.delete(key: _kUsername);
      await _storage.delete(key: _kDisplayName);
      _rememberedUser = null;
    }
    _pendingUser = null;
    _biometricEnabled = false;
    _failedPinAttempts = 0;
    _pendingToken = null;
    _set(SessionStatus.loggedOut);
  }

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  void _set(SessionStatus s) {
    _status = s;
    notifyListeners();
  }
}
