import 'dart:developer';
import 'dart:io' as io;

import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as go;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:testing_api_2/services/network_service.dart';

class DriveViewModel extends ChangeNotifier {
  bool isReady = false;
  bool get fileNotNull => fileList != null && fileList!.files != null;
  bool get userIsNull => _account == null;
  String email = '';
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _account;
  Map<String, String>? _authHeaders;
  GoogleAuthClient? _authenticateClient;
  go.DriveApi? _driveApi;
  go.FileList? fileList;

  String? get getKey {
    String? token = _authHeaders?['Authorization'].toString();
    print(token);
    return token;
  }

  /// tihs sign in method will only run once when the state is ready to launch
  ///
  /// make sure use SchedulerBinding
  ///
  ///
  Future<bool> signIn() async {
    // await _googleSignIn.signOut(); // -> log out
    print('findme ${_account == null}');
    if (!userIsNull) {
      await signOut();
    }

    if (userIsNull) {
      _googleSignIn = GoogleSignIn.standard(scopes: [go.DriveApi.driveScope]);
      _account = await _googleSignIn?.signIn();
      _authHeaders = await _account?.authHeaders;
      if (_authHeaders != null) {
        _authenticateClient = GoogleAuthClient(_authHeaders!);
        NetworkService.initialize(_authHeaders!);
      }
      if (_authenticateClient != null) {
        _driveApi = go.DriveApi(_authenticateClient!);
      }
    }

    log("User account: $_account");

    if (!userIsNull) {
      print('findme ${_account?.email}');
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

  Future<void> listGoogleDriveFiles() async {
    fileList = await _driveApi?.files.list();
    notifyListeners();
  }

  Future<bool> upload(io.File file) async {
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
        return true;
      }
    }
    return false;
  }

  Future<bool> downloadFromDrive(go.File file) async {
    final String? tempPath = await _getDownloadPath();
    final List<int> dataStore = [];
    final StringBuffer sb = StringBuffer();
    final bool downloadable =
        !(file.mimeType?.contains('google-apps') ?? false);
    final bool downloadableDocuments =
        (file.mimeType?.contains('google-apps.document') ?? false);

    sb.write(tempPath);
    sb.write('/');
    sb.write(file.name);

    go.Media? response;
    print('file mime: ${file.mimeType}');

    if (downloadable && file.id != null) {
      response = await _driveApi?.files.get(
        file.id!,
        downloadOptions: go.DownloadOptions.fullMedia,
      ) as go.Media?;
    } else if (downloadableDocuments) {
      print('exported to mime: application/pdf');
      sb.write('.pdf');
      response = await _driveApi?.files.export(
        file.id!,
        'application/pdf',
        downloadOptions: go.DownloadOptions.fullMedia,
      );
    }
    double downloadProgress;

    response?.stream.listen(
      (data) {
        // print("DataReceived: ${data.length}");
        dataStore.insertAll(dataStore.length, data);
        if (response?.length != null) {
          downloadProgress = dataStore.length / response!.length!;
          // print(downloadProgress);
          printer(downloadProgress);
        }
      },
      onDone: () async {
        io.File file = io.File(sb.toString());
        await file.writeAsBytes(dataStore);
        print('Downloaded at: ${sb.toString()}');
      },
      onError: (error) {
        print("Error: $error");
      },
    );

    return response != null;
  }

  Future<String?> _getDownloadPath() async {
    io.Directory? directory;
    try {
      if (io.Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = io.Directory('/storage/emulated/0/Download');
        // Put file in global download folder, if for an unknown reason it didn't exist, we fallback
        // ignore: avoid_slow_async_io
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (err) {
      print("Cannot get download folder path");
    }
    return directory?.path;
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

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
