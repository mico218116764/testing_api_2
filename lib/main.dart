import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:googleapis/drive/v3.dart' as go;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:testing_api_2/drive_vm.dart';
import 'package:testing_api_2/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
    debug: true,
    ignoreSsl: true,
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo Google Drive',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<DriveViewModel>(
            create: (BuildContext context) => DriveViewModel(),
          ),
        ],
        child: const MyHomePage(title: 'Flutter Demo Google Drive'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      print('findme running scheduler binding');
      final DriveViewModel vm = context.read(); //<- extension

      if (await vm.signIn()) {
        print('findme: Sign In Success');
        await vm.listGoogleDriveFiles();
      } else {
        // repeat? ato ask the user to try again or etc.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Consumer<DriveViewModel>(
        builder: (
          BuildContext context,
          DriveViewModel value,
          Widget? child,
        ) =>
            Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.circle,
                  color: value.isReady ? Colors.green : Colors.red,
                ),
                if (value.isReady) const SizedBox(width: 16),
                if (value.isReady) Text(value.email),
              ],
            ),
            if (value.isReady && value.fileNotNull)
              Expanded(
                child: ListView(
                  children: List<Widget>.generate(
                    value.fileList!.files!.length,
                    (int index) {
                      final go.File file = value.fileList!.files![index];
                      return Card(
                        margin: const EdgeInsets.all(4),
                        clipBehavior: Clip.antiAlias,
                        elevation: 4.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  file.name ?? '-',
                                  // overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    bool isSuccess = await context
                                        .read<DriveViewModel>()
                                        .downloadFromDrive(file);
                                    // TODO(Anyone): loading overlay
                                    if (!isSuccess) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                              'Failed to download file'),
                                          content: const Text(
                                            'The file might be not compatible or not downloadable',
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Download'),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();

          if (result != null && result.files.single.path != null) {
            File resultFile = File(result.files.single.path!);

            if (mounted) {
              await context.read<DriveViewModel>().upload(resultFile);
            }
          }
        },
        tooltip: 'Get Files',
        child: const Icon(Icons.upload),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
