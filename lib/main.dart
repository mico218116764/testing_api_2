import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:googleapis/drive/v3.dart' as go;
import 'package:testing_api_2/drive_vm.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
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
      final DriveViewModel vm = context.read(); //<- extension

      if (await vm.signIn()) {
        print('Sign In Success');
      } else {
        // repeat? ato ask the user to try again or etc.
      }
      await vm.listGoogleDriveFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Consumer<DriveViewModel>(
                builder: (context, value, child) {
                  if (value.isReady) {
                    return Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Colors.green,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<DriveViewModel>().signOut();
                          },
                          child: Text('Sign Out'),
                        )
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.red,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          context.read<DriveViewModel>().signIn();
                        },
                        child: Text('Sign In'),
                      )
                    ],
                  );
                },
              ),
              Consumer<DriveViewModel>(
                builder: (context, value, child) {
                  if (value.email != "") {
                    return Text(value.email);
                  }
                  return const Icon(
                    Icons.circle,
                    color: Colors.red,
                  );
                },
              ),
            ],
          ),
          Consumer<DriveViewModel>(
            builder: (context, vm, _) {
              List<go.File>? fileList = vm.fileList?.files;

              if (fileList != null) {
                return Column(
                  children: [
                    for (go.File f in fileList)
                      Card(
                        margin: EdgeInsets.all(4),
                        clipBehavior: Clip.antiAlias,
                        elevation: 4.0,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          width: MediaQuery.of(context).size.width,
                          height: 64,
                          child: Text(
                            f.name ?? '-',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }
              return ElevatedButton(
                onPressed: () {
                  // context.read<DriveViewModel>().listGoogleDriveFiles();
                  // Navigator.push();
                },
                child: Text('Print Files Name'),
              );
            },
          ),
        ],
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
