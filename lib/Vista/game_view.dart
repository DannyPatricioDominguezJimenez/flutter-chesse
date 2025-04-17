import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess/Controlador/game_controller.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_view.dart';

class GameView extends StatefulWidget {
  final String roomId;
  final String playerId;

  const GameView({Key? key, required this.roomId, required this.playerId})
      : super(key: key);

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with WidgetsBindingObserver {
  final ChessBoardController _chessBoardController = ChessBoardController();
  final GameController _gameController = GameController();

  // Turno actual ("white" o "black")
  String _turn = 'white';

  // Info de jugadores
  String _playerColor = ""; // "white" o "black"
  String _playerName = "";
  String _opponentName = "";

  // Oferta de empate
  bool _localDrawOffered = false;
  bool _pendingDrawOffer = false;

  late DatabaseReference _gameRef;
  late DatabaseReference _playersRef;

  // Control de inactividad (5 minutos sin mover)
  Timer? _inactivityTimer;
  DateTime _lastMoveTime = DateTime.now();
  static const int inactivityLimitSeconds = 300; // 5 minutos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameRef = FirebaseDatabase.instance.ref('games/${widget.roomId}');
    _playersRef = _gameRef.child('players');

    _initializeListeners();
    _fetchPlayerInfo();
    _startInactivityTimer();
  }

  /// -------------------------------------------------------
  ///  LISTENERS Y RECONEXIÓN
  /// -------------------------------------------------------
  void _initializeListeners() {
    // Escucha actualizaciones de la sala
    _gameController.listenForBoardUpdates(widget.roomId).listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Partida finalizada
        if (data['status'] == 'finished') {
          final winner = data['winner'] ?? '';
          String result;
          if (winner == 'draw') {
            result = "La partida ha terminado en empate.";
          } else if (winner == "inactividad") {
            result = "Partida finalizada por inactividad.";
          } else {
            result = "¡Jaque mate! Ganador: ${_colorToSpanish(winner)}";
          }
          _showGameOverPopup(result);
          return;
        }

        // Actualizamos turno y tablero
        setState(() {
          _turn = data['turn'] ?? 'white';
        });
        _chessBoardController.loadFen(data['fen'] ?? 'startpos');

        // Oferta de empate del oponente
        if (data['drawOffered'] == true &&
            !_localDrawOffered &&
            !_pendingDrawOffer) {
          _pendingDrawOffer = true;
          _showDrawOfferPopup();
        }
      }
    });
  }

  void _fetchPlayerInfo() async {
    final snapshot = await _playersRef.get();
    if (!snapshot.exists) return;

    final players = Map<String, dynamic>.from(snapshot.value as Map);
    players.forEach((key, value) {
      final data = Map<String, dynamic>.from(value);
      if (key == widget.playerId) {
        _playerColor = data['color'] ?? "";
        _playerName = data['name'] ?? "";
      } else {
        _opponentName = data['name'] ?? "";
      }
    });
    setState(() {});
  }

  void _reconnect() {
    _initializeListeners();
    _fetchPlayerInfo();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Reconectado a la partida.")),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnect();
    }
  }

  /// -------------------------------------------------------
  ///  INACTIVIDAD
  /// -------------------------------------------------------
  void _updateLastMoveTime() {
    _lastMoveTime = DateTime.now();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final secondsInactive =
          DateTime.now().difference(_lastMoveTime).inSeconds;
      if (secondsInactive >= inactivityLimitSeconds) {
        _gameController.endGame(widget.roomId, "inactividad");
        _showGameOverPopup("Partida finalizada por inactividad.");
        _inactivityTimer?.cancel();
      }
    });
  }

  /// -------------------------------------------------------
  ///  MOVIMIENTOS
  /// -------------------------------------------------------
  bool get _absorbBoard => _playerColor != _turn;

  void _onMove() async {
    _updateLastMoveTime();

    // Si no es tu turno, revertimos
    if (_absorbBoard) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No es tu turno.")),
      );
      final fenSnap = await _gameRef.child('fen').once();
      final fenDB = fenSnap.snapshot.value as String? ?? 'startpos';
      _chessBoardController.loadFen(fenDB);
      return;
    }

    final fen = _chessBoardController.getFen();
    final nextTurn = (_turn == 'white') ? 'black' : 'white';

    // Checkmate
    if (_chessBoardController.isCheckMate()) {
      final winner = (_turn == 'white') ? 'black' : 'white';
      await _gameController.endGame(widget.roomId, winner);
      _showGameOverPopup("¡Jaque mate! Ganador: ${_colorToSpanish(winner)}");
      return;
    }

    // Stalemate
    if (_chessBoardController.isStaleMate()) {
      await _gameController.endGame(widget.roomId, "draw");
      _showGameOverPopup("La partida ha terminado en empate.");
      return;
    }

    // Movimiento normal
    await _gameController.makeMove(widget.roomId, fen, nextTurn);
  }

  /// -------------------------------------------------------
  ///  EMPATE
  /// -------------------------------------------------------
  void _showDrawOfferPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Oferta de Empate"),
          content: const Text("El oponente ha ofrecido empate. ¿Aceptas?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Rechaza => resetea la oferta en Firebase
                _gameController.offerDraw(widget.roomId);
                _pendingDrawOffer = false;
              },
              child: const Text("No", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                await _gameController.endGame(widget.roomId, "draw");
                Navigator.of(context).pop();
                _showGameOverPopup("La partida ha terminado en empate.");
              },
              child: const Text("Sí", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  void _offerDraw() async {
    if (_localDrawOffered) return;
    _localDrawOffered = true;
    await _gameController.offerDraw(widget.roomId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Empate ofrecido. Esperando respuesta del oponente.")),
    );
  }

  /// -------------------------------------------------------
  ///  RENDICIÓN
  /// -------------------------------------------------------
  void _resign() async {
    final winner = (_playerColor == 'white') ? 'black' : 'white';
    await _gameController.endGame(widget.roomId, winner);
    _showGameOverPopup("Te has rendido.");
  }

  /// -------------------------------------------------------
  ///  SALIR
  /// -------------------------------------------------------
  Future<bool> _confirmExit() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Salir de la partida"),
              content: const Text(
                  "¿Estás seguro de que deseas abandonar la partida? Se perderá tu progreso."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("No", style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () {
                    final winner =
                        (_playerColor == 'white') ? 'black' : 'white';
                    _gameController.endGame(widget.roomId, winner);
                    Navigator.of(context).pop(true);
                  },
                  child: const Text("Sí", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// -------------------------------------------------------
  ///  POPUP FIN DE PARTIDA
  /// -------------------------------------------------------
  void _showGameOverPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Fin de la Partida"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeView()),
                  (route) => false,
                );
              },
              child: const Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  /// -------------------------------------------------------
  ///  UTILERÍAS
  /// -------------------------------------------------------
  // Convierte "white"/"black" a "Blancas"/"Negras"
  String _colorToSpanish(String color) {
    return color.toLowerCase() == 'white' ? 'Blancas' : 'Negras';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// -------------------------------------------------------
  ///  BUILD
  /// -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Partida de Ajedrez"),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header con degradado y nombres
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.lightBlueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPlayerInfo("Tú", _playerName, _playerColor),
                    _buildPlayerInfo(
                      "Oponente",
                      _opponentName.isEmpty ? "Esperando..." : _opponentName,
                      _playerColor == 'white' ? 'black' : 'white',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tablero con AbsorbPointer si no es tu turno
              Container(
                padding: const EdgeInsets.all(8),
                child: AbsorbPointer(
                  absorbing: _absorbBoard,
                  child: ChessBoard(
                    controller: _chessBoardController,
                    boardColor: BoardColor.brown,
                    boardOrientation: _playerColor == 'white'
                        ? PlayerColor.white
                        : PlayerColor.black,
                    onMove: _onMove,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Indicador de turno
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _playerColor == _turn
                      ? "¡Es tu turno! (${_colorToSpanish(_turn)})"
                      : "Turno: ${_colorToSpanish(_turn)}",
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              // Botones
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _resign,
                      icon: const Icon(Icons.flag),
                      label: const Text("Rendirse"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _offerDraw,
                      icon: const Icon(Icons.handshake),
                      label: const Text("Empate"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(String label, String name, String color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name.isEmpty ? "..." : "$name (${_colorToSpanish(color)})",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }
}
