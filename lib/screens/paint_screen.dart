import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pictionary/models/my_custom_painter.dart';
import 'package:pictionary/models/touch_points.dart';
import 'package:pictionary/screens/final_leaderboard.dart';
import 'package:pictionary/screens/home_screen.dart';
import 'package:pictionary/screens/waiting_lobby_screen.dart';
import 'package:pictionary/sidebar/player_scoreboard_drawer.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PaintScreen extends StatefulWidget {
  final Map<String, String> data;
  final String screenFrom;
  const PaintScreen({super.key, required this.data, required this.screenFrom});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  late IO.Socket _socket;
  Map dataOfRoom = {};
  List<TouchPoints?> points = [];
  StrokeCap strokeType = StrokeCap.round;
  Color selectedColor = Colors.black;
  double opacity = 1;
  double strokeWidth = 2;
  List<Widget> textBlankWidget = [];
  ScrollController _scrollController = ScrollController();
  List<Map> messages = [];
  TextEditingController controller = TextEditingController();
  int guessedUserCounter = 0;
  int _start = 60;
  late Timer _timer;
  var scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map> scoreboard = [];
  bool isTextInputReadOnly = false;
  int maxPoints = 0;
  String winner = "";
  bool isShowFinalLeaderBoard = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connect();
    print(widget.data);
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (timer) {
      if (_start == 0) {
        _socket.emit("change-turn", dataOfRoom['name']);
        setState(() {
          _timer.cancel();
        });
      } else {
        setState(() {
          _start -= 1;
        });
      }
    });
  }

  void renderTextBlank(String text) {
    textBlankWidget.clear();
    print(text);
    for (int i = 0; i < text.length; i++) {
      textBlankWidget.add(
        const Text(
          '_',
          style: TextStyle(fontSize: 30),
        ),
      );
    }
  }

  //socket to client connection
  void connect() {
    _socket = IO.io('http://192.168.0.117:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoconnect': false
    });
    _socket.connect();

    if (widget.screenFrom == 'createRoom') {
      _socket.emit('create-game', widget.data);
    } else {
      _socket.emit("join-game", widget.data);
    }
    // listen to socket
    _socket.onConnect((data) {
      print("connected");
      _socket.on('updateRoom', (roomData) {
        setState(() {
          print(roomData);
          renderTextBlank(roomData['word']);
          dataOfRoom = roomData;
        });
        if (roomData['isJoin'] != true) {
          startTimer();
        }
        scoreboard.clear();
        for (int i = 0; i < roomData['players'].length; i++) {
          setState(() {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          });
        }
      });

      _socket.on(
          'not-correct-game',
          (data) => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
              ));

      _socket.on('points', (point) {
        if (point['details'] != null) {
          setState(() {
            points.add(
              TouchPoints(
                points: Offset((point['details']['dx']).toDouble(),
                    (point['details']['dy']).toDouble()),
                paint: Paint()
                  ..strokeCap = strokeType
                  ..isAntiAlias = true
                  ..color = selectedColor.withOpacity(opacity)
                  ..strokeWidth = strokeWidth,
              ),
            );
          });
        } else {
          setState(() {
            points.add(null);
          });
        }
      });

      _socket.on('msg', (msgData) {
        setState(() {
          messages.add(msgData);
          print(msgData);
          guessedUserCounter = msgData['guessedUserCounter'];
        });
        if (guessedUserCounter == dataOfRoom['players'].length - 1) {
          _socket.emit('change-turn', dataOfRoom['name']);
        }
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 50,
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut);
      });

      _socket.on('change-turn', (data) {
        String oldWord = dataOfRoom['word'];
        print(oldWord);
        showDialog(
            context: context,
            builder: (context) {
              Future.delayed(Duration(seconds: 3), () {
                setState(() {
                  dataOfRoom = data;
                  renderTextBlank(data['word']);
                  isTextInputReadOnly = false;
                  guessedUserCounter = 0;
                  _start = 60;
                  points.clear();
                });
                print("inside Future");
                Navigator.of(context).pop();
                _timer.cancel();
                startTimer();
              });

              return AlertDialog(
                title: Center(child: Text('Word was $oldWord')),
              );
            });
      });

      _socket.on('update-score', (roomData) {
        scoreboard.clear();
        for (int i = 0; i < roomData['players'].length; i++) {
          setState(() {
            scoreboard.add({
              'username': roomData['players'][i]['nickname'],
              'points': roomData['players'][i]['points'].toString()
            });
          });
        }
      });

      _socket.on('show-leaderboard', (roomPlayers) {
        scoreboard.clear();
        for (int i = 0; i < roomPlayers.length; i++) {
          setState(() {
            scoreboard.add({
              'username': roomPlayers[i]['nickname'],
              'points': roomPlayers[i]['points'].toString()
            });
          });
          if (maxPoints < int.parse(scoreboard[i][points])) {
            winner = scoreboard[i]['username'];
            maxPoints = int.parse(scoreboard[i]['points']);
          }
        }
        setState(() {
          _timer.cancel();
          isShowFinalLeaderBoard = true;
        });
      });

      _socket.on('color-change', (colorString) {
        print(colorString);
        int value = int.parse(colorString, radix: 16);
        Color otheColor = Color(value);
        setState(() {
          selectedColor = otheColor;
        });
      });
      _socket.on('stroke-width', (value) {
        setState(() {
          strokeWidth = value.toDouble();
        });
      });
      _socket.on('clear-screen', (data) {
        setState(() {
          points.clear();
        });
      });

      _socket.on('close-input', (_) {
        _socket.emit('update-score', widget.data['name']);
        setState(() {
          isTextInputReadOnly = true;
        });
      });
      _socket.on('user-disconnected', (data) {
        scoreboard.clear();
        for (int i = 0; i < data['players'].length; i++) {
          setState(() {
            scoreboard.add({
              'username': data['players'][i]['nickname'],
              'points': data['players'][i]['points'].toString()
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _socket.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    void selectColor() {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Choose Color'),
                content: SingleChildScrollView(
                  child: BlockPicker(
                      pickerColor: selectedColor,
                      onColorChanged: (color) {
                        String colorString = color.toString();
                        String valueString =
                            colorString.split('(0x')[1].split(')')[0];
                        print(colorString);
                        print(valueString);

                        Map map = {
                          'color': valueString,
                          'roomName': dataOfRoom['name']
                        };
                        _socket.emit('color-change', map);
                        Navigator.of(context).pop();
                      }),
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Close'))
                ],
              ));
    }

    return Scaffold(
      key: scaffoldKey,
      drawer: PlayerScore(userData: scoreboard),
      backgroundColor: Colors.white,
      body: dataOfRoom?.isNotEmpty ?? true
          ? dataOfRoom['isJoin'] != true
              ? !isShowFinalLeaderBoard
                  ? Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: width,
                              height: 0.55 * height,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  if (dataOfRoom['turn'] != null &&
                                      dataOfRoom['turn']['nickname'] ==
                                          widget.data['nickname']) {
                                    _socket.emit('paint', {
                                      'details': {
                                        'dx': details.localPosition.dx,
                                        'dy': details.localPosition.dy,
                                      },
                                      'roomName': widget.data['name'],
                                    });
                                  }
                                },
                                onPanStart: (details) {
                                  if (dataOfRoom['turn'] != null &&
                                      dataOfRoom['turn']['nickname'] ==
                                          widget.data['nickname']) {
                                    _socket.emit('paint', {
                                      'details': {
                                        'dx': details.localPosition.dx,
                                        'dy': details.localPosition.dy,
                                      },
                                      'roomName': widget.data['name'],
                                    });
                                  }
                                },
                                onPanEnd: (details) {
                                  if (dataOfRoom['turn'] != null &&
                                      dataOfRoom['turn']['nickname'] ==
                                          widget.data['nickname']) {
                                    _socket.emit('paint', {
                                      'details': null,
                                      'roomName': widget.data['name'],
                                    });
                                  }
                                },
                                child: SizedBox.expand(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(20),
                                    ),
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size.infinite,
                                        painter:
                                            MyCustomPainter(pointsList: points),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                    onPressed: selectColor,
                                    icon: Icon(
                                      Icons.color_lens,
                                      color: selectedColor,
                                    )),
                                Expanded(
                                  child: Slider(
                                    min: 1.0,
                                    max: 10.0,
                                    activeColor: selectedColor,
                                    value: strokeWidth,
                                    onChanged: (double value) {
                                      Map map = {
                                        'value': value,
                                        'roomName': dataOfRoom['name']
                                      };
                                      _socket.emit('stroke-width', map);
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _socket.emit(
                                        'clear-screen', dataOfRoom['name']);
                                  },
                                  icon: Icon(
                                    Icons.layers_clear,
                                    color: selectedColor,
                                  ),
                                ),
                              ],
                            ),
                            dataOfRoom['turn'] != null &&
                                    widget.data != null &&
                                    dataOfRoom['turn']['nickname'] !=
                                        widget.data['nickname']
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: textBlankWidget)
                                : Center(
                                    child: Text(
                                    dataOfRoom['word'],
                                    style: const TextStyle(fontSize: 30),
                                  )),

                            //Displaying messages
                            Container(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: ListView.builder(
                                  controller: _scrollController,
                                  shrinkWrap: true,
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    var msg = messages[index].values;
                                    return ListTile(
                                      title: Text(
                                        msg.elementAt(0),
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        msg.elementAt(1),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 16),
                                      ),
                                    );
                                  }),
                            ),
                          ],
                        ),
                        dataOfRoom['turn'] != null &&
                                dataOfRoom['turn']['nickname'] !=
                                    widget.data['nickname']
                            ? Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 20),
                                  child: TextField(
                                    readOnly: isTextInputReadOnly,
                                    controller: controller,
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        Map map = {
                                          'username': widget.data['nickname'],
                                          'msg': value.trim(),
                                          'word': dataOfRoom['word'],
                                          'roomName': widget.data['name'],
                                          'guessedUserCounter':
                                              guessedUserCounter,
                                          'totalTime': 60,
                                          'timeTaken': 60 - _start,
                                        };
                                        _socket.emit('msg', map);
                                        controller.clear();
                                      }
                                    },
                                    autocorrect: false,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Colors.transparent),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Colors.transparent),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: const Color(0xffF5F5FA),
                                      hintText: 'Your Guess',
                                      hintStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                              )
                            : Container(),
                        SafeArea(
                          child: IconButton(
                              icon: Icon(Icons.menu, color: Colors.black),
                              onPressed: () =>
                                  scaffoldKey.currentState!.openDrawer()),
                        )
                      ],
                    )
                  : FinalLeaderBoard(
                      scoreboard: scoreboard,
                      winner: winner,
                    )
              : WaitingLobbyScreen(
                  lobbyName: dataOfRoom['name'],
                  numberOfPlayers: dataOfRoom['players'].length,
                  occupancy: dataOfRoom['occupancy'],
                  players: dataOfRoom['players'],
                )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 30),
        child: FloatingActionButton(
          onPressed: () {},
          elevation: 7,
          backgroundColor: Colors.white,
          child: Text(
            '$_start',
            style: TextStyle(color: Colors.black, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
