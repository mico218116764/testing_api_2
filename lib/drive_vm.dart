import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as go;
import 'package:http/http.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DriveViewModel extends ChangeNotifier {
  bool isReady = false;
  bool get isFirst => _account != null;
  String email = "";
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _account;
  Map<String, String>? _authHeaders;
  GoogleAuthClient? _authenticateClient;
  go.DriveApi? _driveApi;
  go.FileList? fileList;

  /// tihs sign in method will only run once when the state is ready to launch
  ///
  /// make sure use SchedulerBinding
  ///
  ///
  Future<bool> signIn() async {
    // await _googleSignIn.signOut(); // -> log out
    if (!isFirst) {
      _googleSignIn ??= GoogleSignIn.standard(scopes: [go.DriveApi.driveScope]);
      _account ??= await _googleSignIn?.signIn();
      _authHeaders ??= await _account?.authHeaders;
      if (_authHeaders != null) {
        _authenticateClient ??= GoogleAuthClient(_authHeaders!);
      }
      if (_authenticateClient != null) {
        _driveApi = go.DriveApi(_authenticateClient!);
      }
    }
    _account ??= await _googleSignIn?.signIn();

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
    _account = null;
    fileList = null;
    email = '-';
    notifyListeners();

    return true;
  }

  Future<void> listGoogleDriveFiles([String? filter]) async {
    String query = filter ?? "name contains '.pdf'";
    if (filter != null) {
      filter = "$filter and name contains '.pdf'";
    }

    fileList = await _driveApi?.files.list(
      spaces: 'drive',
      q: query,
    );

    print(fileList?.files?.length);

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
        // log('Uploaded Drive ID: ${driveFile.id}');
        print('Uploaded Drive ID: ${driveFile.id}');
        await listGoogleDriveFiles();

        return true;
      }
    }
    return false;
  }

  Future<void> downloadFromDrive(String fileId) async {
    // AIzaSyB82HHpNw70oIhhPijaQatSQnquixRFju0
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    final taskId = await FlutterDownloader.enqueue(
      url:
          'https://www.googleapis.com/drive/v3/files/${fileId}?alt=media&key=AIzaSyB82HHpNw70oIhhPijaQatSQnquixRFju0',
      // savedDir: '/storage/emulated/0/Download',
      savedDir: tempPath,
      showNotification:
          true, // show download progress in status bar (for Android)
      openFileFromNotification:
          true, // click on notification to open downloaded file (for Android)
    );
    print(taskId);
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
