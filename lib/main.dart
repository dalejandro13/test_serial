import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:path_provider/path_provider.dart';

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
  int _deviceId, port = 5000;
  TextEditingController _textController = TextEditingController();
  String _networkInterface = "", status = "", route = "", ipAdd = "0.0.0.0";

  sendDataSerial(String line) async{
    _serialData.add(Text(line));
        
    if(line.contains("STATUS")){
      await _port.write(Uint8List.fromList(status.codeUnits));
    }
    else if(line.contains("ROUTE")){
      await _port.write(Uint8List.fromList(route.codeUnits));
    }

    if (_serialData.length > 20) {
      _serialData.removeAt(0);
    }
  }

  startTcpServer() async {
    try{
      Future<ServerSocket> serverFuture = ServerSocket.bind(ipAdd, port);
      serverFuture.then((ServerSocket server) {
        print('Servidor TCP establecido puerto: $port');
        server.listen((Socket socket) {
          socket.listen((List<int> data) {
            String result = String.fromCharCodes(data);
            if(result.contains("ROUTE")){
              route = result;
            } 
            else if(result.contains("STATUS")){
              status = result;
            }
         });
       });
     });
    }
    catch(e){
     print("Error: $e");
    }
  }
  
  getIpInFile() async{
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String doc = appDocDir.path;
    NetworkInterface.list(includeLoopback: false, type: InternetAddressType.any)
    .then((List<NetworkInterface> interfaces) {
      interfaces.forEach((interface) {
        interface.addresses.forEach((address){
          _networkInterface = address.address;
          final File file = File('$doc/ip.txt'); 
          file.writeAsString(_networkInterface).then((value) async {});
        });
      });
    });
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
    await _port.setPortParameters(9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    _transaction = Transaction.stringTerminated(_port.inputStream, Uint8List.fromList([13, 10]));

    _subscription = _transaction.stream.listen((String line) { //detecta cuando algo llega por serial
      setState(() {
        sendDataSerial(line);
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async { //obtiene todos los dispositivos conectados
    _ports = [];
    _puertos = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    devices.forEach((device) {
      String name = device.productName;
      if(name.contains("Mouse") == true || name.contains("mouse") == true || name.contains("MOUSE") == true){
        setState((){
          print("");
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

    startTcpServer();
    getIpInFile();
    
    UsbSerial.usbEventStream.listen((UsbEvent event) { //detecta cuando se ha conectado un dispositivo al USB
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
            _puertos.length > 0
                ? "Dispositivos seriales detectados"
                : "No hay dispositivos seriales",
            style: Theme.of(context).textTheme.headline6),
        //..._ports,
        Text('Status: $_status\n'),
        SizedBox(height: 100.0),
        Text("Result Data", style: Theme.of(context).textTheme.headline6),
        SizedBox(height: 10.0),
        ..._serialData,
      ])),
    ));
  }
}