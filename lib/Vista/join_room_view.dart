import 'package:flutter/material.dart';
import 'package:flutter_chess/Controlador/game_controller.dart';
import 'waiting_room_view.dart';

class JoinRoomView extends StatefulWidget {
  const JoinRoomView({Key? key}) : super(key: key);

  @override
  _JoinRoomViewState createState() => _JoinRoomViewState();
}

class _JoinRoomViewState extends State<JoinRoomView> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  final GameController _gameController = GameController();

  Future<void> _joinRoom() async {
    String roomId = _roomIdController.text.trim();
    String playerName = _playerNameController.text.trim();

    if (roomId.isEmpty || playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Debes ingresar el código de la sala y tu nombre.')));
      return;
    }

    try {
      String playerId = await _gameController.joinRoom(roomId, playerName);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomView(
            roomId: roomId,
            playerId: playerId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.yellow.shade600],
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
                SizedBox(
                  height: 120,
                  child: Image.asset('assets/images/Logo.png',
                      fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                // Tarjeta de ingreso de datos
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
                          "Unirse a una Sala",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Input de Código de Sala (sólo numérico)
                        TextField(
                          controller: _roomIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Código de Sala',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon:
                                Icon(Icons.vpn_key, color: Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Input de Nombre (texto)
                        TextField(
                          controller: _playerNameController,
                          decoration: InputDecoration(
                            labelText: 'Tu Nombre',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon:
                                Icon(Icons.person, color: Colors.blue.shade700),
                          ),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: _joinRoom,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Unirse',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
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
    );
  }
}
