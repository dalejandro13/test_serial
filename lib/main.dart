import 'dart:io';
//import 'package:get_ip/get_ip.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:path_provider_ex/path_provider_ex.dart';

void main() => runApp(MyApp());  

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UsbPort _port;
  String _status = "Idle";
  List<UsbDevice> _puertos = [];
  List<Widget> _ports = [];
  List<Widget> _serialData = [];
  StreamSubscription<String> _subscription;
  Transaction<String> _transaction;
  int _deviceId;
  TextEditingController _textController = TextEditingController();
  //List<StorageInfo> storageInfo = [];
  String _networkInterface = "";

  getIpInFile() async{
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String doc = appDocDir.path;
    print("ruta: $doc");

    //storageInfo = await PathProviderEx.getStorageInfo();
    //print("rutas: $storageInfo");

    NetworkInterface.list(includeLoopback: false, type: InternetAddressType.any)
    .then((List<NetworkInterface> interfaces) {
      setState( () {
        _networkInterface = "";
        interfaces.forEach((interface) {
          _networkInterface += "### name: ${interface.name}\n";
          int i = 0;
          interface.addresses.forEach((address) {
            _networkInterface += "${i++}) ${address.address}\n";
          });
        });
        print("ip: $_networkInterface");
      });
    });

    //String ipAddress = await GetIp.ipAddress;
    //print("direccion IP: $ipAddress");
  }

  Future<bool> _connectTo(device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port.close();
      _port = null;
    }

    if (device == null) {
      _deviceId = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create(); //genera el dialog que pide el permiso de la conexion serial
    if (!await _port.open()) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }

    _deviceId = device.deviceId;
    await _port.setDTR(true);
    await _port.setRTS(true);
    await _port.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port.inputStream, Uint8List.fromList([13, 10]));

    _subscription = _transaction.stream.listen((String line) { //detecta cuando algo llega por serial
      setState(() {
        _serialData.add(Text(line));
        
        print("acaba de llegar: $line");

        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async { //obtiene todos los dispositivos conectados
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    print(devices);

    devices.forEach((device) {
      String name = device.productName;
      if(name.contains("Mouse") == true || name.contains("mouse") == true || name.contains("MOUSE") == true){
        setState((){
          print("el dispositivo es un mouse");
        });
      }
      else{
        _puertos.add(device);
        
        if(_deviceId == device.deviceId){
          _connectTo(null); //llama al metodo para poderse conectar
        }
        else{
          _connectTo(device);
        }
      }
    });

    // setState(() {
    //   print(_ports);
    // });

  }

  @override
  void initState() {
    super.initState();

    getIpInFile();
    
    UsbSerial.usbEventStream.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
        title: const Text('Conexion con dispositivos seriales'),
      ),
      body: Center(
          child: Column(children: <Widget>[
        Text(
            //_ports.length > 0
            _puertos.length > 0
                ? "Dispositivos seriales detectados"
                : "No hay dispositivos seriales",
            style: Theme.of(context).textTheme.headline6),
        //..._ports,
        Text('Status: $_status\n'),
        // ListTile(
        //   title: TextField(
        //     controller: _textController,
        //     decoration: InputDecoration(
        //       border: OutlineInputBorder(),
        //       labelText: 'Text To Send',
        //     ),
        //   ),
        //   trailing: RaisedButton(
        //     child: Text("Send"),
        //     onPressed: _port == null
        //         ? null
        //         : () async {
        //             if (_port == null) {
        //               return;
        //             }
        //             String data = _textController.text + "\r\n";
        //             await _port.write(Uint8List.fromList(data.codeUnits));
        //             _textController.text = "";
        //           },
        //   ),
        // ),
        SizedBox(height: 100.0),
        Text("Result Data", style: Theme.of(context).textTheme.headline6),
        ..._serialData,
      ])),
    ));
  }
}