import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as go;
import 'package:path/path.dart' as p;
import 'package:http/http.dart';

class DriveViewModel extends ChangeNotifier {
  bool isReady = false;
  bool isFirst = false;
  String email = "";
  late final GoogleSignIn? _googleSignIn;
  late final GoogleSignInAccount? _account;
  late final Map<String, String>? _authHeaders;
  late final GoogleAuthClient? _authenticateClient;
  late final go.DriveApi? _driveApi;
  go.FileList? fileList;

  /// tihs sign in method will only run once when the state is ready to launch
  ///
  /// make sure use SchedulerBinding
  ///
  ///
  Future<void> initiate() async {
    _googleSignIn = GoogleSignIn.standard(scopes: [go.DriveApi.driveScope]);
    _account = await _googleSignIn?.signIn();
    _authHeaders = await _account?.authHeaders;
    _authenticateClient = GoogleAuthClient(_authHeaders!);

    _driveApi = go.DriveApi(_authenticateClient!);
  }

  Future<bool> signIn() async {
    // await _googleSignIn.signOut(); // -> log out
    if (!isFirst) {
      initiate();
    }
    _googleSignIn?.signIn();

    log("User account: $_account");

    if (_account != null) {
      isReady = true;
      email = _account!.email;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> signOut() async {
    await _googleSignIn?.signOut();
    isReady = false;
    isFirst = true;
    email = '-';
    notifyListeners();
    return true;
  }

  Future<void> listGoogleDriveFiles() async {
    fileList = await _driveApi?.files.list(spaces: 'drive');
    notifyListeners();
  }

  Future<bool> upload(File file) async {
    if (_driveApi != null) {
      go.File fileToUpload = go.File();
      String? folderId = await _getFolderId();
      if (folderId == null) {
        return false;
      }

      fileToUpload.parents = [folderId];
      fileToUpload.name = p.basename(file.absolute.path);

      //
      go.File driveFile = await _driveApi!.files.create(
        fileToUpload,
        uploadMedia: go.Media(
          file.openRead(),
          file.lengthSync(),
        ),
      );
      if (driveFile.id != null) {
        log('Uploaded Drive ID: ${driveFile.id}');
        return true;
      }
    }
    return false;
  }

  Future<String?> _getFolderId() async {
    const String mimeType = 'application/vnd.google-apps.folder';
    const String folderName = "personalDiaryBackup";

    try {
      final go.FileList? found = await _driveApi?.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName'",
        $fields: "files(id, name)",
      );
      final List<go.File>? files = found?.files;
      if (files == null) {
        log("Sign-in first Error");
        return null;
      }

      // The folder already exists
      if (files.isNotEmpty) {
        return files.first.id;
      }

      // Create a folder
      go.File folder = go.File();
      folder.name = folderName;
      folder.mimeType = mimeType;
      final folderCreation = await _driveApi?.files.create(folder);
      log("Folder ID: ${folderCreation?.id}");

      return folderCreation?.id;
    } catch (e) {
      log(e.toString());
      return null;
    }
  }
}

class GoogleAuthClient extends BaseClient {
  final Map<String, String> _headers;
  final Client _client = Client();

  GoogleAuthClient(this._headers);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
