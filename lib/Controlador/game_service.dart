import 'package:firebase_database/firebase_database.dart';

class GameService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<Map<String, String>> createRoom(String playerName) async {
    String roomId =
        DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13);
    DatabaseReference roomRef = _db.child('games/$roomId');

    final playerRef = roomRef.child('players').push();
    String playerId = playerRef.key!;

    await roomRef.set({
      'status': 'waiting',
      'turn': 'white',
      'fen': 'startpos',
      'history': [],
      'whiteTime': 300,
      'blackTime': 300,
      'players': {
        playerId: {'name': playerName, 'color': 'white', 'isHost': true}
      }
    });

    return {'roomId': roomId, 'playerId': playerId};
  }

  Future<String> joinRoom(String roomId, String playerName) async {
    DatabaseReference roomRef = _db.child('games/$roomId');
    DatabaseEvent event = await roomRef.once();

    if (!event.snapshot.exists) {
      throw Exception('La sala no existe.');
    }

    // Verificamos la cantidad de jugadores actuales
    final playersSnapshot = await roomRef.child('players').get();
    if (playersSnapshot.exists) {
      final playersMap =
          Map<String, dynamic>.from(playersSnapshot.value as Map);
      if (playersMap.length >= 2) {
        throw Exception('La sala ya está llena.');
      }
    }

    final playerRef = roomRef.child('players').push();
    await playerRef
        .set({'name': playerName, 'color': 'black', 'isHost': false});

    return playerRef.key!;
  }

  Stream<DatabaseEvent> getPlayersStream(String roomId) {
    return _db.child('games/$roomId/players').onValue;
  }

  Future<bool> isHost(String roomId, String playerId) async {
    final snapshot =
        await _db.child('games/$roomId/players/$playerId/isHost').get();
    return snapshot.value == true;
  }

  Stream<DatabaseEvent> listenForGameStart(String roomId) {
    return _db.child('games/$roomId/status').onValue;
  }

  Future<void> startGame(String roomId) async {
    await _db.child('games/$roomId').update({'status': 'playing'});
  }

  Stream<DatabaseEvent> listenForBoardUpdates(String roomId) {
    return _db.child('games/$roomId').onValue;
  }

  // 🔹 Corregida: `makeMove` ahora acepta `move` como parámetro opcional
  Future<void> makeMove(String roomId, String fen, String turn,
      [String? move]) async {
    DatabaseReference roomRef = _db.child('games/$roomId');
    DatabaseEvent event = await roomRef.once();

    if (!event.snapshot.exists) {
      throw Exception('La sala no existe.');
    }

    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    List<String> history = List<String>.from(data['history'] ?? []);

    history.add(move ?? "Movimiento desconocido");

    await roomRef.update({
      'fen': fen,
      'turn': turn,
      'history': history,
    });
  }

  Future<void> endGame(String roomId, String winner) async {
    await _db
        .child('games/$roomId')
        .update({'status': 'finished', 'winner': winner});
  }

  Future<void> updateTimer(String roomId, int whiteTime, int blackTime) async {
    await _db.child('games/$roomId/timer').update({
      'whiteTime': whiteTime,
      'blackTime': blackTime,
    });
  }

  Future<void> offerDraw(String roomId) async {
    await _db.child('games/$roomId').update({'drawOffered': true});
  }
}
