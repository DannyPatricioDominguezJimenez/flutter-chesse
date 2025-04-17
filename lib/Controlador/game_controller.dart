import 'package:flutter_chess/Controlador/game_service.dart';
import 'package:firebase_database/firebase_database.dart';

class GameController {
  final GameService _gameService = GameService();

  Future<Map<String, String>> createRoom(String playerName) async {
    return await _gameService.createRoom(playerName);
  }

  Future<String> joinRoom(String roomId, String playerName) async {
    return await _gameService.joinRoom(roomId, playerName);
  }

  Stream<DatabaseEvent> getPlayersStream(String roomId) {
    return _gameService.getPlayersStream(roomId);
  }

  Future<bool> isHost(String roomId, String playerId) async {
    return await _gameService.isHost(roomId, playerId);
  }

  Stream<DatabaseEvent> listenForGameStart(String roomId) {
    return _gameService.listenForGameStart(roomId);
  }

  Future<void> startGame(String roomId) async {
    await _gameService.startGame(roomId);
  }

  Stream<DatabaseEvent> listenForBoardUpdates(String roomId) {
    return _gameService.listenForBoardUpdates(roomId);
  }

  // 🔹 Corregida: Ahora `makeMove` acepta `move` como parámetro opcional
  Future<void> makeMove(String roomId, String fen, String turn,
      [String? move]) async {
    await _gameService.makeMove(
        roomId, fen, turn, move ?? "Movimiento desconocido");
  }

  Future<void> endGame(String roomId, String winner) async {
    await _gameService.endGame(roomId, winner);
  }

  Future<void> updateTimer(String roomId, int whiteTime, int blackTime) async {
    await _gameService.updateTimer(roomId, whiteTime, blackTime);
  }

  Future<void> offerDraw(String roomId) async {
    await _gameService.offerDraw(roomId);
  }
}
