// Nakama 권한 매치. 판 규칙은 두 기기가 실행하고 서버는 행동 순서와 차례 확인을 맡는다.
var PARTY = 1, START = 2, ACTION = 3, ACTION_OK = 4, TURN_END = 5, RESULT = 6, PING = 7;
var TICK_RATE = 5;
var ACTION_TICKS = 45 * TICK_RATE;
var IDLE_TICKS = 90 * TICK_RATE;

function InitModule(ctx, logger, nk, initializer) {
    initializer.registerMatch("dice_pvp", {
        matchInit: matchInit, matchJoinAttempt: matchJoinAttempt, matchJoin: matchJoin,
        matchLeave: matchLeave, matchLoop: matchLoop, matchTerminate: matchTerminate, matchSignal: matchSignal
    });
    initializer.registerMatchmakerMatched(matchmakerMatched);
    logger.info("InitModule: dice_pvp 등록 완료");
}

function matchmakerMatched(ctx, logger, nk, entries) {
    if (entries.length !== 2 || entries[0].presence.userId === entries[1].presence.userId) return;
    var version = entries[0].properties.version;
    if (typeof version !== "string" || !version || version !== entries[1].properties.version ||
        entries[0].properties.mode !== "rank" || entries[1].properties.mode !== "rank") return;
    return nk.matchCreate("dice_pvp", { version: version, users: [entries[0].presence.userId, entries[1].presence.userId] });
}

function matchInit(ctx, logger, nk, params) {
    var seed = parseInt(nk.uuidv4().replace(/-/g, "").slice(0, 8), 16);
    var first = seed % 2;
    return {
        tickRate: TICK_RATE, label: "dice_pvp",
        state: {
            version: params.version, users: params.users, presences: [null, null], parties: [null, null],
            seen: [0, 0], seed: seed, first: first, current_player: first, started: false,
            seq: 0, deadline: IDLE_TICKS, turn_reports: [null, null], results: [null, null],
            awaiting_turn: false, history: []
        }
    };
}

function matchJoinAttempt(ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
    var seat = state.users.indexOf(presence.userId);
    var accepted = seat >= 0 && metadata && metadata.version === state.version &&
        (!state.presences[seat] || state.presences[seat].sessionId === presence.sessionId);
    return { state: state, accept: !!accepted, rejectMessage: accepted ? "" : "version_or_seat" };
}

function broadcast(dispatcher, opcode, payload, recipients) {
    dispatcher.broadcastMessage(opcode, JSON.stringify(payload), recipients || null, null, true);
}

function sendStart(state, dispatcher, presence, seat, resume, tick) {
    broadcast(dispatcher, START, {
        seed: state.seed, first_player: state.first, parties: state.parties, player: seat,
        resume: resume, seq: state.seq, current_player: state.current_player,
        awaiting_turn: state.awaiting_turn, remaining_sec: Math.max(0, Math.ceil((state.deadline - tick) / TICK_RATE))
    }, [presence]);
}

function matchJoin(ctx, logger, nk, dispatcher, tick, state, presences) {
    for (var i = 0; i < presences.length; i++) {
        var presence = presences[i];
        var seat = state.users.indexOf(presence.userId);
        if (seat < 0) continue;
        state.presences[seat] = presence;
        state.seen[seat] = tick;
        if (state.started) {
            sendStart(state, dispatcher, presence, seat, true, tick);
            for (var j = 0; j < state.history.length; j++) {
                broadcast(dispatcher, ACTION_OK, state.history[j], [presence]);
            }
        }
    }
    return { state: state };
}

function matchLeave(ctx, logger, nk, dispatcher, tick, state, presences) {
    for (var i = 0; i < presences.length; i++) {
        var seat = state.users.indexOf(presences[i].userId);
        if (seat >= 0 && state.presences[seat] && state.presences[seat].sessionId === presences[i].sessionId) {
            // 소켓이 끊겼을 때는 같은 계정에 재접속 기회를 준다. 명시적 나가기는 즉시 처리한다.
            state.presences[seat] = null;
        }
    }
    return { state: state };
}

function integer(value, min, max) {
    return typeof value === "number" && value >= min && value <= max && Math.floor(value) === value;
}

function validParty(value) {
    if (!value || typeof value.name !== "string" || value.name.length < 2 || value.name.length > 40 ||
        !value.levels || !Array.isArray(value.deck) || value.deck.length > 15) return false;
    var slots = ["attack", "defense", "support"];
    for (var i = 0; i < slots.length; i++) {
        var slot = slots[i];
        if (typeof value[slot] !== "string" || !/^[a-z0-9_]{1,48}$/.test(value[slot]) ||
            !integer(value.levels[slot], 1, 5)) return false;
    }
    return value.attack !== value.defense && value.attack !== value.support && value.defense !== value.support &&
        value.deck.every(function (id) { return typeof id === "string" && /^[a-z0-9_]{1,48}$/.test(id); });
}

function validAction(value) {
    if (!value || !Array.isArray(value.args)) return false;
    var arg = value.args[0];
    switch (value.type) {
        case "roll": return value.args.length === 1 && (arg === "" || arg === "low" || arg === "high");
        case "ability": return value.args.length === 1 && (arg === "attack" || arg === "defense" || arg === "support");
        case "card": return value.args.length === 1 && integer(arg, 0, 20);
        case "choice": return value.args.length === 1 && integer(arg, 0, 20);
        case "end_turn": return value.args.length === 0;
        default: return false;
    }
}

function forwardAction(state, dispatcher, tick, type, args) {
    var action = { seq: ++state.seq, player: state.current_player, type: type, args: args };
    state.history.push(action);
    broadcast(dispatcher, ACTION_OK, action);
    state.deadline = tick + ACTION_TICKS;
    state.awaiting_turn = type === "end_turn" || type === "auto";
}

function finish(dispatcher, winner, reason) {
    broadcast(dispatcher, RESULT, { winner: winner, reason: reason });
    return null;
}

function matchLoop(ctx, logger, nk, dispatcher, tick, state, messages) {
    for (var i = 0; i < messages.length; i++) {
        var message = messages[i];
        var seat = state.users.indexOf(message.sender.userId);
        if (seat < 0 || !state.presences[seat] || state.presences[seat].sessionId !== message.sender.sessionId) continue;
        state.seen[seat] = tick;
        if (message.opCode === PING) continue;
        var body;
        try {
            var text = nk.binaryToString(message.data);
            if (text.length > 8192) continue;
            body = JSON.parse(text);
        } catch (error) { continue; }
        if (!body || typeof body !== "object") continue;
        if (message.opCode === RESULT && body.reason === "leave") return finish(dispatcher, 1 - seat, "leave");
        if (!state.started) {
            if (message.opCode === PARTY && !state.parties[seat] && validParty(body)) state.parties[seat] = body;
            if (state.parties[0] && state.parties[1] && state.presences[0] && state.presences[1]) {
                state.started = true;
                state.deadline = tick + ACTION_TICKS;
                sendStart(state, dispatcher, state.presences[0], 0, false, tick);
                sendStart(state, dispatcher, state.presences[1], 1, false, tick);
            }
            continue;
        }
        if (message.opCode === ACTION && seat === state.current_player && !state.awaiting_turn &&
            !state.results[0] && !state.results[1] && body.seq === state.seq && validAction(body)) {
            forwardAction(state, dispatcher, tick, body.type, body.args);
        } else if (message.opCode === TURN_END && state.awaiting_turn && body.seq === state.seq &&
            body.next_player === 1 - state.current_player && typeof body.hash === "string" &&
            /^[a-f0-9]{64}$/.test(body.hash)) {
            if (!state.turn_reports[seat]) state.turn_reports[seat] = body;
            if (state.turn_reports[0] && state.turn_reports[1]) {
                if (state.turn_reports[0].hash !== state.turn_reports[1].hash) return finish(dispatcher, -1, "sync_error");
                state.current_player = body.next_player;
                state.turn_reports = [null, null];
                state.awaiting_turn = false;
                state.deadline = tick + ACTION_TICKS;
                broadcast(dispatcher, TURN_END, { seq: state.seq, next_player: state.current_player });
            }
        } else if (message.opCode === RESULT && body.seq === state.seq && integer(body.winner, 0, 2) &&
            typeof body.hash === "string" && /^[a-f0-9]{64}$/.test(body.hash)) {
            if (!state.results[seat]) state.results[seat] = body;
            if (state.results[0] && state.results[1]) {
                if (state.results[0].winner !== state.results[1].winner || state.results[0].hash !== state.results[1].hash) {
                    return finish(dispatcher, -1, "sync_error");
                }
                return finish(dispatcher, body.winner, "finished");
            }
        }
    }
    if (!state.started) {
        if (tick >= state.deadline) return finish(dispatcher, -1, "cancelled");
        return { state: state };
    }
    var idle0 = tick - state.seen[0] >= IDLE_TICKS;
    var idle1 = tick - state.seen[1] >= IDLE_TICKS;
    if (idle0 || idle1) return finish(dispatcher, idle0 && idle1 ? -1 : (idle0 ? 1 : 0), "leave");
    if (tick >= state.deadline) {
        if (state.awaiting_turn || state.results[0] || state.results[1]) {
            if (tick >= state.deadline + ACTION_TICKS) return finish(dispatcher, -1, "sync_error");
        } else {
            forwardAction(state, dispatcher, tick, "auto", []);
        }
    }
    return { state: state };
}

function matchTerminate(ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
    return finish(dispatcher, -1, "cancelled");
}

function matchSignal(ctx, logger, nk, dispatcher, tick, state, data) {
    return { state: state, data: "" };
}
