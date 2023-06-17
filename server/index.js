const express = require("express");
var http = require("http");
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
const mongoose = require("mongoose");
const Room = require("./models/Room");
var io = require("socket.io")(server);
const getWord = require("./api/getWord");
//middle
app.use(express.json());

//connect to database
const DB =
  "mongodb+srv://John:deathkiller3699@cluster0.lcsqtyb.mongodb.net/?retryWrites=true&w=majority";

mongoose
  .connect(DB)
  .then(() => {
    console.log("Connection is Successful!!");
  })
  .catch((e) => {
    console.log(e);
  });

io.on("connection", (socket) => {
  console.log("Connected io");
  //create game callback
  socket.on("create-game", async ({ nickname, name, occupancy, maxRounds }) => {
    try {
      const existingRoom = await Room.findOne({ name });
      if (existingRoom) {
        socket.emit("notCorrectGame", "Room with that name already exists!");
        return;
      }
      let room = new Room();
      const word = getWord();
      room.word = word;
      room.name = name;
      room.occupancy = occupancy;
      room.maxRounds = maxRounds;
      let player = {
        socketID: socket.id,
        nickname,
        isPartyLeader: true,
      };
      room.players.push(player);
      room = await room.save();
      console.log("Room Created");
      socket.join(name);
      io.to(name).emit("updateRoom", room);
    } catch (err) {
      console.log(err);
    }
  });
  socket.on("join-game", async ({ nickname, name }) => {
    console.log("inside join-game");
    try {
      let room = await Room.findOne({ name });
      if (!room) {
        socket.emit("not-correct-game", "Please enter a valid room name");
        return;
      }

      if (room.isJoin) {
        let player = {
          socketID: socket.id,
          nickname: nickname,
        };
        room.players.push(player);
        console.log(room);
        socket.join(name);
        if (room.players.length === room.occupancy) {
          room.isJoin = false;
        }
        room.turn = room.players[room.turnIndex];
        room = await room.save();

        io.to(name).emit("updateRoom", room);
      } else {
        socket.emit(
          "notCorrectGame",
          "The game is in progress, Please try later"
        );
        return;
      }
    } catch (err) {
      console.log(err);
    }
  });

  //
  socket.on("msg", async (data) => {
    try {
      if (data.msg === data.word) {
        let room = await Room.find({ name: data.roomName });
        let userPlayer = room[0].players.filter(
          (player) => player.nickname === data.username
        );

        if (data.timeTaken !== 0) {
          userPlayer[0].points += Math.round((200 / data.timeTaken) * 10);
        }

        room = await room[0].save();
        io.to(data.roomName).emit("msg", {
          username: data.username,
          msg: "Guessed it!",
          guessedUserCounter: data.guessedUserCounter + 1,
        });
        socket.emit("close-input", "");
      } else {
        io.to(data.roomName).emit("msg", {
          username: data.username,
          msg: data.msg,
          guessedUserCounter: data.guessedUserCounter,
        });
      }
    } catch (err) {
      console.log(err.toString());
    }
  });

  socket.on("change-turn", async (name) => {
    try {
      let room = await Room.findOne({ name });
      let idx = room.turnIndex;
      if (idx + 1 === room.players.length) {
        room.currentRound += 1;
      }
      if (room.currentRound <= room.maxRounds) {
        const word = getWord();
        room.word = word;
        room.turnIndex = (idx + 1) % room.players.length;
        room.turn = room.players[room.turnIndex];
        room = await room.save();
        io.to(name).emit("change-turn", room);
      } else {
        //show the leaderboard
        io.to(name).emit("show-leaderboard", room.players);
      }
    } catch (err) {
      console.log(err);
    }
  });

  //Start drawing on the screen
  socket.on("paint", ({ details, roomName }) => {
    console.log(details);
    // if (details === null) {
    //   console.log("in here");
    //   details = "NullValue";
    // }
    io.to(roomName).emit("points", { details: details });
  });

  //change Color
  socket.on("color-change", ({ color, roomName }) => {
    io.to(roomName).emit("color-change", color);
  });

  //Change Stroke width
  socket.on("stroke-width", ({ value, roomName }) => {
    io.to(roomName).emit("stroke-width", value);
  });

  //clear screen
  socket.on("clear-screen", (roomName) => {
    io.to(roomName).emit("clear-screen", roomName);
  });

  //update score
  socket.on("update-score", async (name) => {
    try {
      const room = await Room.findOne({ name });
      io.to(name).emit("update-score", room);
    } catch (err) {
      console.log(err);
    }
  });

  socket.on("disconnect", async () => {
    try {
      let room = await Room.findOne({ "players.socketID": socket.id });
      console.log(room);
      if (room) {
        for (let i = 0; i < room.players.length; i++) {
          if (room.players[i].socketID === socket.id) {
            room.players.splice(i, 1);
            break;
          }
        }
      }
      room = await room.save();
      if (room.players.length === 1) {
        socket.broadcast.to(room.name).emit("show-leaderboard", room.players);
      } else {
        socket.broadcast.to(room.name).emit("user-disconnected", room);
      }
    } catch (err) {
      console.log(err);
    }
  });
});

server.listen(port, "0.0.0.0", () => {
  console.log("Server started" + port);
});
