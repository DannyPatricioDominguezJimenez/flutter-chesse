import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_chess/Controlador/game_controller.dart';
import 'game_view.dart';

class WaitingRoomView extends StatefulWidget {
  final String roomId;
  final String playerId;

  const WaitingRoomView({
    Key? key,
    required this.roomId,
    required this.playerId,
  }) : super(key: key);

  @override
  _WaitingRoomViewState createState() => _WaitingRoomViewState();
}

class _WaitingRoomViewState extends State<WaitingRoomView> {
  final GameController _gameController = GameController();
  late Stream<DatabaseEvent> _playersStream;
  List<String> _players = [];
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _playersStream = _gameController.getPlayersStream(widget.roomId);
    _checkIfHost();
    _listenForGameStart();
  }

  void _checkIfHost() async {
    bool isHost = await _gameController.isHost(widget.roomId, widget.playerId);
    setState(() {
      _isHost = isHost;
    });
  }

  void _listenForGameStart() {
    _gameController.listenForGameStart(widget.roomId).listen((event) {
      if (event.snapshot.value != null && event.snapshot.value == 'playing') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameView(
              roomId: widget.roomId,
              playerId: widget.playerId,
            ),
          ),
        );
      }
    });
  }

  Future<void> _startGame() async {
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Se necesitan al menos 2 jugadores para iniciar.')),
      );
      return;
    }
    await _gameController.startGame(widget.roomId);
  }

  /// Función que muestra un diálogo de confirmación al presionar "back".
  Future<bool> _confirmExit() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Salir de la sala"),
              content: const Text(
                  "¿Estás seguro de que deseas abandonar la sala? Se perderá tu progreso."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("No", style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Sí", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit, // Intercepta el botón de retroceso
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 Logo
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),

                  // 🏠 Tarjeta de información de la sala
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Sala de Espera",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🔹 Código de la sala
                          Text(
                            "Código de Sala: ${widget.roomId}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // 🔹 Lista de jugadores en la sala
                          StreamBuilder<DatabaseEvent>(
                            stream: _playersStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }

                              if (snapshot.hasError) {
                                return const Text(
                                    'Error al cargar los jugadores.');
                              }

                              if (snapshot.hasData &&
                                  snapshot.data!.snapshot.value != null) {
                                final playersData = Map<String, dynamic>.from(
                                    snapshot.data!.snapshot.value as Map);
                                _players = playersData.values
                                    .map((player) => player['name'] as String)
                                    .toList();

                                return Column(
                                  children: [
                                    const Text(
                                      "Jugadores en la sala:",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // 🔹 Mostramos la lista de jugadores en la sala
                                    ..._players.map(
                                      (name) => ListTile(
                                        leading: const Icon(Icons.person,
                                            color: Colors.blueAccent),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // 🔹 Botón "Iniciar Partida" (Solo visible si es host)
                                    if (_isHost)
                                      ElevatedButton(
                                        onPressed: _players.length >= 2
                                            ? _startGame
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 24),
                                          backgroundColor:
                                              Colors.green.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Iniciar Partida',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                );
                              }

                              return const Text('Esperando jugadores...');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
