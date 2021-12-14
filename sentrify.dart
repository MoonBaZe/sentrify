#! /usr/bin/env dcli

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const znnService = 'go-zenon.service';
const ipifyIpsV4 = ['3.232.242.170', '52.20.78.240', '54.91.59.199', '3.220.57.224'];
const ipifyIpsV6 = ['108.171.202.195', '108.171.202.203', '108.171.202.211'];

const optionBootstrap = 'Bootstrap';
const optionAddSentry = 'AddSentry';
const optionEmptyPeers = 'EmptyPeers';
const optionSentrify = 'Sentrify';
const optionUnsentrify = 'Unsentrify';
const optionHelp = 'Help';
const optionQuit = 'Quit';

Future<void> main() async {
  _checkSuperuser();

  var _ipv4json = await Ipify.ipv4();

  if (_ipv4json.isNotEmpty) {
    print('IP address: ' + green(_ipv4json));
  } else {
    print(red('Error!') + ' Not connected to the Internet or ipv6');
    exit(0);
  }

  var _selected =
  menu(prompt: 'Select an option from the ones listed above\n', options: [
    optionBootstrap,
    optionAddSentry,
    optionEmptyPeers,
    optionSentrify,
    optionUnsentrify,
    optionHelp,
    optionQuit
  ]);

  if (_selected == 'Quit') {
    exit(0);
  }

  ensureDirectoriesExist();

  var _znnConfigFilePath =
      znnDefaultDirectory.absolute.path + separator + 'config.json';
  var _znnConfigFile = File(_znnConfigFilePath);

  if (!_znnConfigFile.existsSync()) {
    touch(_znnConfigFilePath, create: true);
    _znnConfigFile.writeAsStringSync('{}');
  }

  var _configJson = _parseConfig(znnDefaultDirectory.absolute.path);

  switch (_selected) {
    case optionBootstrap:
      var downloadUrl = ask('Please enter the bootstrap download url:');
      bool running = _isZNNServiceActive();
      if(running) {
        _stopZNNService();
      }

      _downloadBootstrap(downloadUrl);

      if(running) {
        _startZNNService();
      }
      print('Successfully downloaded and unzipped bootstrap.zip');
      break;
    case optionAddSentry:
      String sentryIP = ask('Please enter the sentry ip:');
      String sentryPort = ask('Please enter the sentry websocket port (35998 default):');
      try {
        sentryPort = int.parse(sentryPort).toString();
      } catch (e) {
        sentryPort = '35998';
      }
      var peer = 'enode://';
      try {
        final Zenon znnClient = Zenon();
        String _urlOption = 'ws://' + sentryIP + ':' + sentryPort;
        await znnClient.wsClient.initialize(_urlOption, retry: false);
        NetworkInfo nInfo = await znnClient.stats.networkInfo();

        sentryPort = '35995';
        peer += nInfo.self.publicKey + '@' + sentryIP + ':' +  sentryPort;
        znnClient.wsClient.stop();
      } catch (e) {
        print(e);
        print('Can not establish a connection with the sentry');
        break;
      }

      if (!_configJson.containsKey('Net')) {
        _configJson['Net'] = {'Seeders': []};
      } else if (!_configJson['Net'].containsKey('Seeders')) {
        _configJson['Net']['Seeders'] = [];
      }
      if (!_configJson['Net']['Seeders'].contains(peer)) {
        _configJson['Net']['Seeders'].add(peer);
      }
      _writeConfig(_configJson, znnDefaultDirectory.absolute.path);
      print('Successfully added sentry');
      break;
    case optionEmptyPeers:
      if (!_configJson.containsKey('Net')) {
        _configJson['Net'] = {'Seeders': []};
      } else {
        _configJson['Net']['Seeders'] = [];
      }
      _writeConfig(_configJson, znnDefaultDirectory.absolute.path);
      print('Successfully removed all peers');
      break;
    case optionSentrify:
      var peers = getPeers(_configJson);
      var maxPeers = peers.length;
      var minPeers = maxPeers > 2 ? 2 : maxPeers;

      if (!_configJson.containsKey('Net')) {
        _configJson['Net'] = {
          'MinPeers': minPeers,
          'MaxPeers': maxPeers
        };
      } else {
        _configJson['Net']['MinPeers'] = minPeers;
        _configJson['Net']['MaxPeers'] = maxPeers;
      }
      _writeConfig(_configJson, znnDefaultDirectory.absolute.path);

      print(Process.runSync('ufw', ['disable'], runInShell: true).stdout);

      Process.runSync('ufw', ['default', 'deny', 'outgoing'], runInShell: true);
      Process.runSync('ufw', ['default', 'deny', 'incoming'], runInShell: true);

      // Allow ssh
      print(Process.runSync('ufw', ['allow', 'ssh'], runInShell: true).stdout);

      // Allow dns
      print(Process.runSync('ufw', ['allow', 'out', '53'], runInShell: true).stdout);

      // Allow ipify ips v4
      for (var peerIp in ipifyIpsV4) {
        print(Process.runSync('ufw', ['allow', 'out', 'to', peerIp], runInShell: true).stdout);
        print(Process.runSync('ufw', ['allow', 'in', 'from', peerIp], runInShell: true).stdout);
      }

      // Allow ipify ips v6
      for (var peerIp in ipifyIpsV6) {
        print(Process.runSync('ufw', ['allow', 'out', 'to', peerIp], runInShell: true).stdout);
        print(Process.runSync('ufw', ['allow', 'in', 'from', peerIp], runInShell: true).stdout);
      }

      for (var peer in peers) {
        var socket = peer.split('@')[1];
        // Only handles ipv4 for now
        var peerIp = socket.split(':')[0];
        var peerPort = socket.split(':')[1];

        // Allow communication with configured sentries
        print(Process.runSync('ufw', ['allow', 'out', 'to', peerIp], runInShell: true).stdout);
        print(Process.runSync('ufw', ['allow', 'in', 'from', peerIp], runInShell: true).stdout);
      }

      Process.runSync('ufw', ['enable'], runInShell: true);

      print(await Process.runSync('ufw', ['status'], runInShell: true).stdout);
      break;
    case optionUnsentrify:
      if(_isZNNServiceActive()) {
        _stopZNNService();
      }
      Process.runSync('ufw', ['disable'], runInShell: true);
      break;
    case optionHelp:
      print('Bootstrap - will download bootstrap.zip from the provided url and unzip it in the default directory');
      print('AddSentry - will ask for the sentry ip and port and add it as peer in the config');
      print(
          'EmptyPeers - will remove all peers from the config');
      print('Sentrify - will allow connections with the configured sentries and ssh and deny all other');
      print('Unsentrify - will stop znnd service and then disable the firewall rules');
      print('Help');
      print('Quit');
      break;
    default:
      break;
  }
}

dynamic getPeers(dynamic _configJson) {
  var peers = [];
  if (!_configJson.containsKey('Net')) {
    return peers;
  } else if (!_configJson['Net'].containsKey('Seeders')) {
    return peers;
  }

  for(var peer in _configJson['Net']['Seeders']) {
    peers.add(peer);
  }
  return peers;
}

void _checkSuperuser() {
  if (Shell.current.isPrivilegedUser) {
    print('Running with ' + green('superuser privileges'));
  } else {
    print('Some commands require ' +
        green('superuser privileges') +
        ' in order to successfully complete. Please run using superuser privileges');
    exit(0);
  }
}

Map _parseConfig(String znnInstallationPath) {
  var config = File(znnInstallationPath + separator + 'config.json');
  if (config.existsSync()) {
    String data = config.readAsStringSync();
    Map map = json.decode(data);
    return map;
  }
  return {};
}

String _formatJSON(Map<dynamic, dynamic> j) {
  var spaces = ' ' * 4;
  var encoder = JsonEncoder.withIndent(spaces);
  return encoder.convert(j);
}

void _writeConfig(Map config, String znnInstallationPath) {
  var configFile = File(znnInstallationPath + separator + 'config.json');
  configFile.writeAsStringSync(_formatJSON(config));
}

bool _isZNNServiceActive() {
  var processResult =
  Process.runSync('systemctl', ['is-active', znnService], runInShell: true);
  return processResult.stdout.toString().startsWith('active');
}

void _stopZNNService({int delay = 2}) {
  if (_isZNNServiceActive()) {
    print('Stopping $znnService ...');
    Process.runSync('systemctl', ['stop', znnService], runInShell: true);
    sleep(delay);
  }
}

void _startZNNService({int delay = 2}) {
  if (!_isZNNServiceActive()) {
    print('Starting $znnService ...');
    Process.runSync('systemctl', ['enable', znnService], runInShell: true);
    Process.runSync('systemctl', ['start', znnService], runInShell: true);
    sleep(delay);
  }
}

void _removeBootstrapFiles() {
  File bootstrapFile = File('/root/.znn/bootstrap.zip');
  if(bootstrapFile.existsSync()) {
    bootstrapFile.deleteSync();
  }
  var nomDir = Directory('/root/.znn/nom');
  if(nomDir.existsSync()) {
    nomDir.deleteSync(recursive: true);
  }
  var consensusDir = Directory('/root/.znn/consensus');
  if(consensusDir.existsSync()) {
    consensusDir.deleteSync(recursive: true);
  }
}

void _downloadBootstrap(var downloadUrl) {
  _removeBootstrapFiles();
  print('Preparing to download bootstrap');

  try {
    fetch(
        url: downloadUrl,
        saveToPath: '/root/.znn/bootstrap.zip',
        fetchProgress: (progress) {
          switch (progress.status) {
            case FetchStatus.connected:
              print('Starting the download ...');
              break;
            case FetchStatus.complete:
              print('File downloaded ' + green('successfully'));
              break;
            case FetchStatus.error:
              print(red('Error!') + ' File not downloaded. Please retry!');
              break;
            default:
              break;
          }
        });
  } catch (e) {
    print('${red('Download error!')}: $e');
    exit(0);
  }

  print(Process.runSync('unzip', ['/root/.znn/bootstrap.zip', '-d', '/root/.znn/'], runInShell: true).stdout);
}