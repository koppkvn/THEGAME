// index.js - WebSocket game server for Tactical Duel
import { WebSocketServer } from "ws";
import { createInitialState, applyAction } from "./rules.js";

const PORT = process.env.PORT || 3000;

// Room storage
const rooms = new Map();

// Generate 4-character room code
function generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

// Create WebSocket server
const wss = new WebSocketServer({ port: PORT });

console.log(`🎮 Tactical Duel server running on port ${PORT}`);

wss.on("connection", (ws) => {
    console.log("New connection");

    let playerRoom = null;
    let playerId = null;

    ws.on("message", (data) => {
        let msg;
        try {
            msg = JSON.parse(data.toString());
        } catch {
            return;
        }

        console.log("Received:", msg.type);

        switch (msg.type) {
            case "CREATE_ROOM": {
                const roomCode = generateRoomCode();
                rooms.set(roomCode, {
                    players: [ws],
                    state: null,
                    playerIds: ["P1"],
                });
                playerRoom = roomCode;
                playerId = "P1";

                ws.send(JSON.stringify({
                    type: "ROOM_CREATED",
                    roomCode,
                    playerId: "P1",
                }));
                console.log(`Room created: ${roomCode}`);
                break;
            }

            case "JOIN_ROOM": {
                const code = msg.roomCode?.toUpperCase();
                const room = rooms.get(code);

                if (!room) {
                    ws.send(JSON.stringify({ type: "ERROR", message: "Room not found" }));
                    return;
                }

                if (room.players.length >= 2) {
                    ws.send(JSON.stringify({ type: "ERROR", message: "Room is full" }));
                    return;
                }

                room.players.push(ws);
                room.playerIds.push("P2");
                playerRoom = code;
                playerId = "P2";

                ws.send(JSON.stringify({
                    type: "ROOM_JOINED",
                    roomCode: code,
                    playerId: "P2",
                }));

                // Start the game
                room.state = createInitialState();

                // Notify both players
                const startMsg = JSON.stringify({
                    type: "GAME_START",
                    state: room.state,
                });
                room.players.forEach((p) => p.send(startMsg));
                console.log(`Game started in room ${code}`);
                break;
            }

            case "ACTION": {
                if (!playerRoom) return;
                const room = rooms.get(playerRoom);
                if (!room || !room.state) return;

                const action = msg.action;

                // Validate it's this player's turn (for non-END_TURN actions)
                if (action.type !== "END_TURN" && action.playerId !== playerId) {
                    ws.send(JSON.stringify({ type: "ERROR", message: "Not your turn" }));
                    return;
                }

                // For END_TURN, use the actual current player
                if (action.type === "END_TURN") {
                    action.playerId = room.state.turn.currentPlayerId;
                    // Only allow ending your own turn
                    if (action.playerId !== playerId) {
                        ws.send(JSON.stringify({ type: "ERROR", message: "Not your turn" }));
                        return;
                    }
                }

                // Apply action
                const newState = applyAction(room.state, action);

                if (newState === room.state) {
                    ws.send(JSON.stringify({ type: "ERROR", message: "Invalid action" }));
                    return;
                }

                room.state = newState;

                // Broadcast new state to all players
                const updateMsg = JSON.stringify({
                    type: "STATE_UPDATE",
                    state: room.state,
                });
                room.players.forEach((p) => {
                    if (p.readyState === 1) p.send(updateMsg);
                });
                break;
            }
        }
    });

    ws.on("close", () => {
        console.log("Connection closed");
        if (playerRoom) {
            const room = rooms.get(playerRoom);
            if (room) {
                // Notify other player
                room.players.forEach((p) => {
                    if (p !== ws && p.readyState === 1) {
                        p.send(JSON.stringify({ type: "PLAYER_DISCONNECTED" }));
                    }
                });
                // Clean up room
                rooms.delete(playerRoom);
                console.log(`Room ${playerRoom} closed`);
            }
        }
    });
});
